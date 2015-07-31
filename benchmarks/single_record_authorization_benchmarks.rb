require 'benchmark'
require 'active_record'
require 'authorization_attrs'

require './spec/support/setup_authorization_attrs_table.rb'

class User < ActiveRecord::Base
  has_many :articles, foreign_key: :owner_id
end

class Article < ActiveRecord::Base
  belongs_to :owner, class_name: "User", foreign_key: :owner_id
end

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Migration.create_table "users" do |t|
    t.string  :name
  end

  ActiveRecord::Migration.create_table "articles" do |t|
    t.string  :title
    t.boolean :public
    t.integer :owner_id
  end

  ActiveRecord::Migration.add_index("articles", ["owner_id", "public"])
end

module Authorizations
  class ArticleAuthorizations
    def self.record_attrs(article)
      [{ public: article.public }, { owner_id: article.owner_id }]
    end

    def initialize(user)
      @user = user
    end

    def edit
      [{ public: true }, { owner_id: user.id }]
    end

    private

    attr_reader :user
  end
end

class SingleRecordAuthorizationBenchmarks
  def self.execute
    new.execute
  end

  def execute
    users = 10.times.map { User.create(name: "Anybody") }
    users.each do |user|
      50.times.map { Article.create(title: "Tacos", owner: user, public: false) }
      50.times.map { Article.create(title: "Tacos", owner: user, public: true) }
    end

    user = users.first.reload
    article = user.articles.where(public: true).first

    Article.find_each do |article|
      AuthorizationAttrs.reset_attrs_for(article)
    end

    Benchmark.bm do |t|
      t.report("attrs") { AttrStrategy.edit(article, user) }
      t.report("direct") { ComparisonStrategy.edit(article, user) }
    end
  end

  module AttrStrategy
    def self.edit(article, user)
      AuthorizationAttrs.authorized?(:edit, Article, article.id, user)
    end
  end

  module ComparisonStrategy
    def self.edit(article, user)
      article.public || user.id == article.owner_id
    end
  end
end
