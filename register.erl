-module(register).

-export([registerUser/0,recieveMessage/1,signInUser/0,getUsersList/0,userSubscriberMap/1,subscribeToUser/1,userProcessIdMap/1
,signOutUser/0]).

registerUser()->
    {ok,[UserName]}=io:fread("Enter Username","~ts"),
    {ok,[PassWord]}=io:fread("Enter Password","~ts"),
    {ok,[Email]}=io:fread("Enter Email","~ts"),
    ServerConnectionId=spawn(list_to_atom("server@HB33"),mainclass, bufferSignIn,[]),
    ServerConnectionId ! {UserName,PassWord,Email,self(),register},
    receive
        {Registered}->
            io:format("~s~n",[Registered])    
    end.

recieveMessage(UserPasswordMap)->
    receive
        {UserName,PassWord,_,Pid,RemoteNodePid}->
            User=maps:find(UserName,UserPasswordMap),
            if
                User==error->
                    NewUserMap=maps:put(UserName,PassWord,UserPasswordMap), 
                    receiveTweet ! {UserName},
                    Pid ! {"Registered",RemoteNodePid},                  
                    recieveMessage(NewUserMap);
                true ->
                    Pid ! {"Error while Registering",RemoteNodePid},
                    recieveMessage(UserPasswordMap) 
            end;
        {UserName,PasswordAndProcess,Pid,RemoteNodePid}->
            UserPassword=maps:find(UserName,UserPasswordMap),
            [Pass,Process]=PasswordAndProcess,
            ListPassWord={ok,Pass},
            if
                UserPassword==ListPassWord-> 
                   userProcessIdMap!{UserName,Process,"Morning Mate"}, 
                   Pid ! {"Signed In",RemoteNodePid}; 
                true ->
                    Pid ! {"Wrong UserName or Password",RemoteNodePid} 
            end,
            recieveMessage(UserPasswordMap);
        {UserName,Pid}->
            User=maps:find(UserName,UserPasswordMap),
            if
                User==error->
                    Pid ! {"ok"};
                true ->
                    Pid ! {"not ok"}     
            end,
            recieveMessage(UserPasswordMap);
        {Pid,RemoteNodePid,_}->
            UserList=maps:to_list(UserPasswordMap),
            Pid ! {UserList,RemoteNodePid},
            recieveMessage(UserPasswordMap) 
    end.
signInUser()->
    {ok,[UserName]}=io:fread("Enter Username","~ts"),
    {ok,[PassWord]}=io:fread("Enter Password","~ts"),
    ServerConnectionId=spawn(list_to_atom("server@HB33"),mainclass, bufferSignIn,[]),
    persistent_term:put("ServerId", ServerConnectionId),
    register(receiveTweetFromUser,spawn(sendreceive,receiveTweetFromUser,[])),

    ServerConnectionId!{UserName,[PassWord,whereis(receiveTweetFromUser)],self()},   
    receive
        {Registered}->
            if
                Registered=="Signed In"->
                    persistent_term:put("UserName",UserName),
                    persistent_term:put("SignedIn",true);
                true->
                    persistent_term:put("SignedIn",false)      
            end,
            io:format("~s~n",[Registered])  
    end.

getUsersList()->
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true-> 
            RemoteServerId=persistent_term:get("ServerId"),
            RemoteServerId!{self()},   
            receive
                {UserList}->
                    % io:format("~p~n",[Registered])  
                    printList(UserList,1)
            end;
        true->
            io:format("You should sign in to send tweets Call mainclass:startTheRegistration() to complete signin~n")
    end.

userSubscriberMap(UserSubscriberMap)->
    receive
    {UserName,CurrentUserName,CurrentUserPid,Pid,RemoteNodePid}->
        ListSubscribers=maps:find(UserName,UserSubscriberMap),
        if
            ListSubscribers==error->
                NewUserSubscriberMap=maps:put(UserName,[{CurrentUserName,CurrentUserPid}],UserSubscriberMap),
                Pid ! {"Subscribed",RemoteNodePid},
                userSubscriberMap(NewUserSubscriberMap); 
            true ->
                {ok,Subscribers}=ListSubscribers,
                io:format("~p~n",[Subscribers]),
                Subscribers1=lists:append(Subscribers,[{CurrentUserName,CurrentUserPid}]),
                io:format("UserName ~p ~p~n",[UserName,Subscribers1]),
                NewUserSubscriberMap=maps:put(UserName,Subscribers1,UserSubscriberMap),
                % io:format("~p",NewUserTweetMap),
                Pid ! {"Subscribed",RemoteNodePid},                
                userSubscriberMap(NewUserSubscriberMap)  
        end;
    {UserName,Pid}->
        ListSubscribers=maps:find(UserName,UserSubscriberMap),
        if
            ListSubscribers==error->
                Pid !{[]};
            true->
                {ok,Subscribers}=ListSubscribers,
                Pid ! {Subscribers}     
        end,         
        userSubscriberMap(UserSubscriberMap)     
    end.   

printList(UserList,Index)->
    if
        Index>length(UserList)->
            ok;
        true->
            {UserName,_}=lists:nth(Index,UserList),
            io:format("~s~n",[UserName]),
            printList(UserList,Index+1)
    end.
subscribeToUser(UserName)->
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true-> 
            RemoteServerId=persistent_term:get("ServerId"),
            RemoteServerId!{UserName,persistent_term:get("UserName"),self(),whereis(receiveTweetFromUser)},   
            receive
                {Registered}->
                    io:format("~p~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call mainclass:startTheRegistration() to complete signin~n")
    end.
userProcessIdMap(UserProcessIdMap)->
    receive
    {UserName,CurrentUserPid,_}->
        NewUserProcessIdMap=maps:put(UserName,CurrentUserPid,UserProcessIdMap),  
        io:format("~p~n",[NewUserProcessIdMap]),              
        userProcessIdMap(NewUserProcessIdMap); 
    {UserName,RemoteNodePid,Pid,_}->
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                Pid ! {"",RemoteNodePid},
                userProcessIdMap(UserProcessIdMap); 
            true ->
                NewUserProcessIdMap=maps:remove(UserName,UserProcessIdMap),  
                Pid ! {"SignedOut",RemoteNodePid},    

                userProcessIdMap(NewUserProcessIdMap)     
        end;  
    {UserName,Tweet}->
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                ok;
            true->
                {ok,ProcessId}=ListSubscribers,
                ProcessId ! {Tweet,UserName}   
        end,         
        userProcessIdMap(UserProcessIdMap)     
    end.  
signOutUser()->
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true-> 
            RemoteServerId=persistent_term:get("ServerId"),
            RemoteServerId!{[persistent_term:get("UserName"),self()],signOut},
            receive
                {Registered}->
                    persistent_term:erase("UserName"),
                    io:format("~s~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call mainclass:startTheRegistration() to complete signin~n")    
    end.        








