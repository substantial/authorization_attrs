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

class AuthorizationBenchmarks
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

  def without_required_db_access
    users = 10.times.map { User.create(name: "Anybody") }
    users.each do |user|
      10.times.map { Article.create(title: "Tacos", owner: user, public: false) }
      10.times.map { Article.create(title: "Tacos", owner: user, public: true) }
    end

    first_user = users.first.reload
    first_user_articles = Article.where(public: false, owner: first_user)
    first_article = first_user_articles.first

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison does not hit the database\n\n"

    puts "\t single record authorization"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.edit(first_article, first_user) }
      t.report("direct") { ComparisonStrategy.edit(first_article, first_user) }
    end

    puts "\t multiple record authorization"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.edit_multiple(first_user_articles, first_user) }
      t.report("direct") { ComparisonStrategy.edit_multiple(first_user_articles, first_user) }
    end

    puts "\t searching by permission"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.edit_search(first_user) }
      t.report("direct") { ComparisonStrategy.edit_search(first_user) }
    end
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

    available_articles =  Article.where(public: false, owner: different_user, group: available_group)
    unavailable_articles =  Article.where(public: false, owner: different_user, group: off_limits_group)

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison hits the database\n\n"

    puts "\t single record authorization"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.view(available_articles.first, test_user) }
      t.report("direct") { ComparisonStrategy.view(available_articles.first, test_user) }
    end

    puts "\t multiple record authorization - none match (fastest for direct)"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.view_multiple(unavailable_articles, test_user) }
      t.report("direct") { ComparisonStrategy.view_multiple(unavailable_articles, test_user) }
    end

    puts "\t multiple record authorization - all match (slowest for direct)"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.view_multiple(available_articles, test_user) }
      t.report("direct") { ComparisonStrategy.view_multiple(available_articles, test_user) }
    end

    puts "\t searching by permission"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.view_search(test_user) }
      t.report("direct") { ComparisonStrategy.view_search(test_user) }
    end
  end

  module AttrStrategy
    def self.view(article, user)
      AuthorizationAttrs.authorized?(:view, Article, article.id, user)
    end

    def self.edit(article, user)
      AuthorizationAttrs.authorized?(:edit, Article, article.id, user)
    end

    def self.view_multiple(articles, user)
      AuthorizationAttrs.authorized?(:view, Article, articles.map(&:id), user)
    end

    def self.edit_multiple(articles, user)
      AuthorizationAttrs.authorized?(:edit, Article, articles.map(&:id), user)
    end

    def self.view_search(user)
      AuthorizationAttrs.find_by_permission(:view, Article, user)
    end

    def self.edit_search(user)
      AuthorizationAttrs.find_by_permission(:edit, Article, user)
    end
  end

  module ComparisonStrategy
    def self.view(article, user)
      article.public ||
        article.owner_id == user.id ||
        user.group_users.pluck(:group_id).include?(article.group_id)
    end

    def self.edit(article, user)
      article.public || user.id == article.owner_id
    end

    def self.view_multiple(articles, user)
      articles.all? { |article| view(article, user) }
    end

    def self.edit_multiple(articles, user)
      articles.all? { |article| edit(article, user) }
    end

    def self.view_search(user)
      Article.all.to_a.select { |article| view(article, user) }
    end

    def self.edit_search(user)
      Article.all.to_a.select { |article| edit(article, user) }
    end
  end
end
