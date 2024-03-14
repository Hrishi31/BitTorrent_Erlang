-module(sendreceive).

-export([tweetSendtoServer/1, retrieveTweetfromUser/1, mapHashTagTweet/1,parseTheTweet/5,receiveTweetFromUser/0,sendTweetToAllSubscribers/4]).

tweetSendtoServer(Tweet)->
    try persistent_term:get("SignedIn")
    catch 
    error:X ->
        io:format("~p~n",[X])
    end,  
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true-> 
            RemoteServerId=persistent_term:get("ServerId"),
            RemoteServerId!{persistent_term:get("UserName"),Tweet,self(),tweet},
            receive
                {Registered}->
                    io:format("~s~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call mainclass:startTheRegistration() to complete signin~n")
    end. 


retrieveTweetfromUser(UserTweetMap)->
    receive
        {UserName,Tweet,Pid,RemoteNodePid}->
            ListTweets=maps:find(UserName,UserTweetMap),
            if
                ListTweets==error->
                    Pid ! {"User Not present in Server Database",RemoteNodePid},
                    retrieveTweetfromUser(UserTweetMap);
                true ->
                    {ok,Tweets}=ListTweets,
                    io:format("~s~n",[Tweet]),
                    io:format("~p~n",[Tweets]),
                    Tweets1=lists:append(Tweets,[Tweet]),
                    io:format("~p~n",[Tweets1]),
                    NewUserTweetMap=maps:put(UserName,Tweets1,UserTweetMap), 
                    Pid ! {"Tweet Posted",RemoteNodePid},  
                    TweetSplitList=string:split(Tweet," ",all),
                    io:format("~p~n",[TweetSplitList]),
                    parseTheTweet(TweetSplitList,1,Tweet,UserName,"#"),
                    parseTheTweet(TweetSplitList,1,Tweet,UserName,"@"),
                    subscribeToUser ! {UserName,self()},
                    receive
                        {Subscribers}->
                          io:format("Subscribers are ~p~n",[Subscribers]),
                          spawn(sendreceive,sendTweetToAllSubscribers,[Subscribers,1,Tweet,UserName])
                    end,                  
                    retrieveTweetfromUser(NewUserTweetMap)
            end;
         {UserName}->
            NewUserTweetMap=maps:put(UserName,[],UserTweetMap),
            retrieveTweetfromUser(NewUserTweetMap);
         {UserName,Pid,RemoteNodePid}->
            ListTweets=maps:find(UserName,UserTweetMap),
            if
                ListTweets==error->
                    Pid ! {[],RemoteNodePid};
                true ->
                    {ok,Tweets}=ListTweets,
                    io:format("length= ~p~n",[length(Tweets)]),
                    Pid ! {Tweets,RemoteNodePid}
            end,
            retrieveTweetfromUser(UserTweetMap)
    end. 


mapHashTagTweet(HashTagTweetMap)->
   receive
    {HashTag,Tweet,UserName,addnewhashTag}->
        io:format("~s~n",[Tweet]),
        ListTweets=maps:find(HashTag,HashTagTweetMap),
        if
            ListTweets==error->
                NewHashTagTweetMap=maps:put(HashTag,[{Tweet,UserName}],HashTagTweetMap),
                mapHashTagTweet(NewHashTagTweetMap);
            true ->
                {ok,Tweets}=ListTweets,
                io:format("~p~n",[Tweets]),
                Tweets1=lists:append(Tweets,[{Tweet,UserName}]),
                io:format("~p~n",[Tweets1]),
                NewHashTagTweetMap=maps:put(HashTag,Tweets1,HashTagTweetMap),
                % io:format("~p",NewUserTweetMap),                
                mapHashTagTweet(NewHashTagTweetMap)
        end;
     {HashTag,Pid,RemoteNodePid}->
        ListTweets=maps:find(HashTag,HashTagTweetMap),
        if
            ListTweets==error->
                Pid ! {[],RemoteNodePid};
            true ->
                {ok,Tweets}=ListTweets,
                io:format("~p~n",[Tweets]),
                Pid ! {Tweets,RemoteNodePid}
        end,
        mapHashTagTweet(HashTagTweetMap)
    end. 
parseTheTweet(SplitTweet,Index,Tweet,UserName,Tag)->
    if
        Index==length(SplitTweet)+1 ->
         ok;
        true ->
            CurrentString=string:find(lists:nth(Index,SplitTweet),Tag,trailing),
            io:format("~s~n",[CurrentString]),
            if
                CurrentString==nomatch ->
                  ok;  
                true ->
                    hashTagMap ! {CurrentString,Tweet,UserName,addnewhashTag}  
            end,
            parseTheTweet(SplitTweet,Index+1,Tweet,UserName,Tag)
    end.

sendTweetToAllSubscribers(Subscribers,Index,Tweet,UserName)->
 if
    Index>length(Subscribers)->
            ok;
    true->
        {Username1,_}=lists:nth(Index,Subscribers),
        % io:format("~p~n",[Pid]),
        userProcessIdMap!{Username1,Tweet},
        sendTweetToAllSubscribers(Subscribers,Index+1,Tweet,UserName)
 end.       

receiveTweetFromUser()->
    receive
     {Message,UserName}->
        CurrentMessage=UserName++" : "++Message,
        io:format("~s~n",[CurrentMessage]),
        receiveTweetFromUser()
    end.

       



    



 