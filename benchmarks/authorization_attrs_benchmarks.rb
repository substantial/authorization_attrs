require 'benchmark'
require 'active_record'
require 'database_cleaner'
require 'authorization_attrs'

require './spec/support/setup_authorization_attrs_table.rb'

class User < ActiveRecord::Base
  has_many :articles, foreign_key: :owner_id
  has_many :groups, through: :group_users
  has_many :group_users
end

class Article < ActiveRecord::Base
  belongs_to :owner, class_name: "User", foreign_key: :owner_id
  belongs_to :group
  has_many :authorization_attrs, as: :authorizable
end

class GroupUser < ActiveRecord::Base
  belongs_to :group
  belongs_to :user
end

class Group < ActiveRecord::Base
  has_many :articles
  has_many :users, through: :group_users
  has_many :group_users
end

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Migration.create_table "users" do |t|
    t.string  :name
  end

  ActiveRecord::Migration.create_table "articles" do |t|
    t.string  :title
    t.boolean :public
    t.integer :owner_id
    t.integer :group_id, index: true
  end

  ActiveRecord::Migration.create_table "group_users" do |t|
    t.integer :user_id, index: true
    t.integer :group_id, index: true
  end

  ActiveRecord::Migration.create_table "groups" do |t|
    t.string :name
  end

  ActiveRecord::Migration.add_index("articles", ["owner_id", "public"])
end

module Authorizations
  class ArticleAuthorizations
    def self.record_attrs(article)
      [
        { public: article.public },
        { owner_id: article.owner_id },
        { group_id: article.group_id }
      ]
    end

    def initialize(user)
      @user = user
    end

    def view
      [
        articles_in_my_group,
        public_articles,
        articles_written_by_me
      ].flatten
    end

    def edit
      [
        public_articles,
        articles_written_by_me
      ].flatten
    end

    private

    def articles_in_my_group
      GroupUser.where(user: user).pluck(:group_id).map { |id| { group_id: id } }
    end

    def public_articles
      { public: true }
    end

    def articles_written_by_me
      { owner_id: user.id }
    end

    attr_reader :user
  end
end

class AuthorizationAttrsBenchmarks
  def self.execute
    new.execute
  end

  def execute
    benchmarks = [
      :without_required_db_access,
      :with_required_db_access
    ]

    DatabaseCleaner.strategy = :transaction

    benchmarks.each do |bm|
      DatabaseCleaner.cleaning do
        send(bm)
        puts "\n"
      end
    end
  end

  private

  def perform_benchmark(method_name, label, *args)
    puts "\t #{label}"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.send(method_name, *args) }
      t.report("direct") { DirectStrategy.send(method_name, *args) }
    end
  end

  def without_required_db_access
    users = 10.times.map { User.create(name: "Anybody") }
    users.each do |user|
      10.times.map { Article.create(title: "Tacos", owner: user, public: false) }
      10.times.map { Article.create(title: "Tacos", owner: user, public: true) }
    end

    test_user = users.first.reload
    available_article_ids = Article.where(public: false, owner: test_user).pluck(:id)

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison rarely hits the database\n\n"

    perform_benchmark(:edit, "single record authorization", available_article_ids.first, test_user)
    perform_benchmark(:edit_multiple, "multiple record authorization", available_article_ids, test_user)
    perform_benchmark(:edit_search, "search by permission", test_user)
  end

  def with_required_db_access
    users = 10.times.map { User.create(name: "Anybody") }
    groups = 10.times.map { Group.create(name: "Cool People") }

    groups.each do |group|
      users.each do |user|
        10.times.map { GroupUser.create(user: user, group: group) }
        10.times.map { Article.create(title: "Tacos", owner: user, group: group, public: false) }
        10.times.map { Article.create(title: "Tacos", owner: user, group: group, public: true) }
      end
    end

    available_group = groups.first.reload
    off_limits_group = groups.last.reload

    test_user = users.first.reload
    different_user = users.last.reload
    test_user.group_users.where(group: off_limits_group).destroy_all

    available_article_ids =  Article.where(public: false, owner: different_user, group: available_group).pluck(:id)
    unavailable_article_ids =  Article.where(public: false, owner: different_user, group: off_limits_group).pluck(:id)

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison frequently hits the database\n\n"

    perform_benchmark(:view, "single record authorization", available_article_ids.first, test_user)
    perform_benchmark(:view_multiple, "multiple record authorization - none match (fastest for direct)", unavailable_article_ids, test_user)
    perform_benchmark(:view_multiple, "multiple record authorization - all match (slowest for direct)", available_article_ids, test_user)
    perform_benchmark(:view_search, "search by permission", test_user)
  end

  module AttrStrategy
    def self.view(article_id, user)
      AuthorizationAttrs.authorized?(:view, Article, article_id, user)
    end

    def self.edit(article_id, user)
      AuthorizationAttrs.authorized?(:edit, Article, article_id, user)
    end

    def self.view_multiple(article_ids, user)
      AuthorizationAttrs.authorized?(:view, Article, article_ids, user)
    end

    def self.edit_multiple(article_ids, user)
      AuthorizationAttrs.authorized?(:edit, Article, article_ids, user)
    end

    def self.view_search(user)
      AuthorizationAttrs.find_by_permission(:view, Article, user)
    end

    def self.edit_search(user)
      AuthorizationAttrs.find_by_permission(:edit, Article, user)
    end
  end

  module DirectStrategy
    def self.view(article_id, user)
      article = find_if_id(article_id)

      article.public ||
        article.owner_id == user.id ||
        user.group_users.pluck(:group_id).include?(article.group_id)
    end

    def self.view_multiple(article_ids, user)
      articles = Article.find(article_ids)

      articles.all? { |article| view(article, user) }
    end

    def self.view_search(user)
      Article.all.select { |article_id| view(article_id, user) }
    end

    def self.edit(article_id, user)
      article = find_if_id(article_id)

      article.public || user.id == article.owner_id
    end

    def self.edit_multiple(article_ids, user)
      articles = Article.find(article_ids)

      articles.all? { |article| edit(article, user) }
    end

    def self.edit_search(user)
      Article.all.select { |article_id| edit(article_id, user) }
    end

    def self.find_if_id(article_id)
      if article_id.is_a? Integer
        Article.find(article_id)
      else
        article_id
      end
    end
  end
end
