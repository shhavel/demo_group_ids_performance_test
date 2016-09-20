require "bundler/setup"
Bundler.require
COUNT = ENV["COUNT"].to_i
raise "Please provide environment variable COUNT" if COUNT == 0
puts "One post belongs to #{COUNT} groups"

class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :name, null: false
    end
  end
end

class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :name, null: false
      t.integer :group_ids, array: true, default: [], null: false
    end
  end
end

class CreateGroupsPosts < ActiveRecord::Migration
  def change
    create_table :groups_posts
    add_reference :groups_posts, :group, index: true, foreign_key: {to_table: :groups}
    add_reference :groups_posts, :post, index: true, foreign_key: {to_table: :posts}
  end
end

ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "localhost", database: "demo_test", username: "postgres", password: "postgres")
CreateGroups.new.change
CreatePosts.new.change
CreateGroupsPosts.new.change

class Group < ActiveRecord::Base; end
class Post < ActiveRecord::Base; end
class GroupsPost < ActiveRecord::Base; end

groups = []
count = 0
(1..200_000).each do |group_id|
  groups << Group.new(id: group_id, name: Faker::Company.name)
  if group_id % 1000 == 0
    Group.import groups
    groups = []
    count += 1000
    puts "Inserted #{count} groups" if group_id % 10000 == 0
  end
end

posts = []
groups_posts = []
count = 0
(1..4_000_000).each do |post_id|
  group_ids = Array.new(COUNT) { rand(1..200_000) }
  posts << Post.new(id: post_id, name: Faker::Lorem.sentence, group_ids: group_ids)
  group_ids.each do |group_id|
    groups_posts << GroupsPost.new(group_id: group_id, post_id: post_id)
  end
  if post_id % 1000 == 0
    Post.import posts
    posts = []
    count += 1000
    puts "Inserted #{count} posts" if post_id % 10000 == 0
    GroupsPost.import groups_posts
    groups_posts = []
  end
end

class CreateGroupIdsIndexOnPosts < ActiveRecord::Migration
  def change
    execute "CREATE EXTENSION IF NOT EXISTS intarray;"
    execute "CREATE INDEX posts_group_ids_rdtree_index ON posts USING GIST (group_ids gist__int_ops);"
    # execute "CREATE INDEX posts_group_ids_rdtree_index ON posts USING GIST (group_ids gin__int_ops);"
  end
end

CreateGroupIdsIndexOnPosts.new.change
