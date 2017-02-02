require 'sinatra'
require 'data_mapper'

DataMapper.setup(:default, "sqlite:///#{Dir.pwd}/data.db")

set :sessions, true

set :bind, '0.0.0.0'

class User
	include DataMapper::Resource
	property :id       , Serial
	property :username , String
	property :password , String
	property :friends  , String,:length=>2000
	property :nick_name, String
	property :gender   , String
end

class Comment
	include DataMapper::Resource
	property :id      	, Serial     
	property :user_id 	, Integer
	property :post_id	, Integer
	property :giver	  	, String
	property :time	  	, String
	property :soft_del	, Boolean
	property :content   , String,:length=>2000
end

class Post
	include DataMapper::Resource
	property :id      	, Serial     
	property :user_id 	, Integer
	property :content 	, String
	property :likes   	, Integer
	property :giver	  	, String
	property :time	  	, String
	property :soft_del	, Boolean
	property :show_comment   , Boolean
	property :who_liked , String,:length=>2000
end

DataMapper.finalize
User.auto_upgrade!
Post.auto_upgrade!
Comment.auto_upgrade!

get '/' do
	
	if session[:id]
		redirect '/login'
		return
	end
	erb :front

end

get '/signup' do
	erb :signup	
end

post '/delete_post' do
	post = Post.all({:id=>params[:id]}).first
	post.soft_del = true
	post.save
	redirect '/wall'
end

post '/show_friends' do
	friend_list = User.all({:id=>session[:id]}).first.friends.split("(@)")
	
	user_list = []

	friend_list.each do |friend|
		if friend.eql?session[:id].to_s
			next
		end
		
		user = User.get(friend.to_i)
		if user != nil
			user_list<<user.username
		end
		
	end

	erb :show_friends , locals:{id: session[:id] , user_list: user_list}
end

get '/login' do 
	
	if session[:id]
		user = User.get(session[:id])
		if user
			puts "going into the wall"
			redirect '/wall' 
		else
			session[:id]=nil
		end
	end
	erb :login
end

post '/edit_post' do
	id = params[:id]
	post = Post.all({:id=>id}).first
	erb :edit_post , locals: {id: post.id}
end

post '/delete_comment' do
	comment = Comment.all({:id=>params[:id]}).first
	comment.destroy()
	redirect '/wall'
end

post '/save_edit_post' do
	id = params[:id]
	post = Post.all({:id=>id}).first
	post.content = params[:content]
	post.save
	redirect '/wall'
end

post '/comment' do
	id = params[:id]
	comment_list = Comment.all({:post_id=>id})
	comment = Comment.new
	comment.user_id = session[:id]
	comment.post_id = id
	comment.giver = User.get(session[:id]).username
	comment.time = Time.now.to_s
	post = Post.all({:id=>id}).first
	comment.content = nil
	comment.save
	erb :comments_page , locals: { post: post , comment_list: comment_list , comment_id: comment.id }
end

post '/show_comment' do
	post = Post.all({:id=>params[:id]}).first
	post.show_comment = !post.show_comment
	post.save
	redirect '/wall'
end

post '/add_comment' do
	comment = Comment.all({:id=>params[:comment_id]}).first
	comment.content = params[:content]
	if comment.content==nil || comment.content==" "
		comment.destroy
	end
	comment.save
	redirect '/wall'
end

post '/verify' do
	username = params[:username]
	password = params[:password]

	user = User.all({:username=>username,:password=>password}).first

	if user
		session[:id]=user.id
		redirect '/wall'
	else 
		redirect '/login'
	end
		

end

get '/logout' do
	session[:id]=nil
	redirect 'login'
end

get '/wall' do
	user = User.get(session[:id])
	
	# list = User.all()
	# var = String.new
	# list.each do |user|
	# 	puts user.friends
	# 	user.friends = var
	# 	user.save
	# end	

	user = User.get(session[:id])
	
	post_list = Post.all()

	comment_list = Comment.all()  

	erb :wall , locals: {user: user , post_list: post_list , comment_list: comment_list}
end

post '/register' do
	username = params[:username]
	password = params[:password]
	user = User.all({:username=>username}).first

	if user
		redirect '/signup'
	end 

	user = User.new
	user.password = password
	user.username = username 
	user.nick_name = "frog"
	user.gender = "idiot"
	user.save
	user.friends = user.id.to_s 
	user.save
	session[:username] = username
	session[:password] = password
	session[:id]  = user.id
	redirect '/login'
end

post '/post_like' do
	id = params[:id]
	current = Post.all({:id=>id}).first
	likers_list = nil

	
	if current.who_liked
		likers_list = current.who_liked.split("(@)")
	end

	if (likers_list) && (likers_list.include?session[:id].to_s)
		current.likes -= 1
		current.who_liked = nil
		likers_list.each do |liker_id|
			if( liker_id.eql?session[:id].to_s )
				next
			end
			if current.who_liked
				current.who_liked = current.who_liked + "(@)" + liker_id 
			else
				current.who_liked = liker_id
			end	
		end
	else
		if current.who_liked
			current.who_liked = current.who_liked + "(@)" + session[:id].to_s 
		else
			current.who_liked = session[:id].to_s
		end
		current.likes += 1
	end
	current.save
	redirect '/wall'
end

post '/new_post' do
	user_id = params[:user_id]
	content = params[:content]
	post = Post.new
	post.user_id = user_id
	post.content = content
	post.likes = 0
	post.show_comment = false
	post.soft_del = false
	post.who_liked = nil
	post.time = Time.now.to_s
	post.giver = params[:giver]
	post.save
	redirect '/wall'
end

post '/find_friend' do
	user = User.all({:id=>session[:id]}).first
	friend = User.all(:username=>params[:name]).first
	found = false
	if friend
		found = true
	end

	erb :find_friends , locals: {found: found , friend: friend , user: user}
end

post '/add_friend' do
	
	user = User.all({:id=>session[:id]}).first
	friend = User.all({:id=>params[:friend_id]}).first
	contain = params[:contain]

	puts contain.class
	puts contain

	if contain.eql?"true"
		puts "removing friend"
		friend_list = user.friends.split("(@)")
		temp = String.new
		friend_list.each do |this_one|
			if( this_one.eql?params[:friend_id].to_s)
				next
			end
			temp = temp + this_one + "(@)"
		end	
		user.friends = temp
		puts "removing friend"
		friend_list = friend.friends.split("(@)")
		temp = String.new
		friend_list.each do |this_one|
			if( this_one.eql?session[:id].to_s)
				next
			end
			temp = temp + this_one + "(@)"
		end
		friend.friends = temp
		puts "removing friend"
		user.save
		friend.save

		redirect '/wall'
		puts "removing friend"
		puts "removing friend"
		puts "removing friend"
	
	else
		if user.friends
			user.friends = user.friends + "(@)" + friend.id.to_s 
			friend.friends = friend.friends  + "(@)" + user.id.to_s 
		else  
			puts "reinitialised"
			user.friends = friend.id.to_s 
			friend.friends = user.id.to_s 
		end
		user.save
		friend.save
		redirect '/wall'
	end
end









































