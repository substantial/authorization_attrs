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
      :single_record_without_required_db_access,
      :single_record_with_required_db_access
    ]

    DatabaseCleaner.strategy = :transaction

    benchmarks.each do |bm|
      DatabaseCleaner.cleaning do
        send(bm)
      end
    end
  end

  private

  def single_record_without_required_db_access
    users = 10.times.map { User.create(name: "Anybody") }
    users.each do |user|
      10.times.map { Article.create(title: "Tacos", owner: user, public: false) }
      10.times.map { Article.create(title: "Tacos", owner: user, public: true) }
    end

    user = users.first.reload
    article = Article.where(public: false, owner: user).first

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison does not hit the database"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.edit(article, user) }
      t.report("direct") { ComparisonStrategy.edit(article, user) }
    end
  end

  def single_record_with_required_db_access
    users = 10.times.map { User.create(name: "Anybody") }
    groups = 10.times.map { Group.create(name: "Cool People") }

    groups.each do |group|
      users.each do |user|
        10.times.map { GroupUser.create(user: user, group: group) }
        10.times.map { Article.create(title: "Tacos", owner: user, group: group, public: false) }
        10.times.map { Article.create(title: "Tacos", owner: user, group: group, public: true) }
      end
    end

    first_user = users.first.reload
    last_user = users.last.reload
    article = Article.where(public: false, owner: last_user).first

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    puts "When direct comparison hits the database"
    Benchmark.bm(7) do |t|
      t.report("attrs") { AttrStrategy.view(article, first_user) }
      t.report("direct") { ComparisonStrategy.view(article, first_user) }
    end
  end

  module AttrStrategy
    def self.view(article, user)
      AuthorizationAttrs.authorized?(:view, Article, article.id, user)
    end

    def self.edit(article, user)
      AuthorizationAttrs.authorized?(:edit, Article, article.id, user)
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
  end
end
