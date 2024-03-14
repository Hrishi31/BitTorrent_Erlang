-module(mainclass).

-export([registrationStart/0, twitterStart/0, bufferSignIn/0,tweetSend/0, retrieveUserList/0,subscribe/0, signInAndOut/0]).

registrationStart()->
    io:format("~s~n",["Welcome to the twitter clone"]),
    {ok,[SignIn]}=io:fread("Do you want to Sign In or register. Enter S for Signing In and Enter R for Registration","~ts"),
    if
        (SignIn=="S")->
            register:signInUser();
        true->
            register:registerUser()
    end.
bufferSignIn()->
    receive
        % for SignIn
        {UserName,PasswordAndProcess,Pid}->
            userregister ! {UserName,PasswordAndProcess,self(),Pid};
        % for Registeration    
        {UserName,PassWord,Email,Pid,register}->
            userregister ! {UserName,PassWord,Email,self(),Pid};      
        {UserName,Tweet,Pid,tweet}->
            receiveTweet !{UserName,Tweet,self(),Pid};
        {UserName,Pid}->
            if 
                Pid==signOut->
                    [UserName1,RemoteNodePid]=UserName,
                    userProcessIdMap!{UserName1,RemoteNodePid,self(),randomShitAgain};
                true->
                 receiveTweet !{UserName,self(),Pid}
            end;     
        {Pid}->
            userregister ! {self(),Pid,"goodMorningMate"};    
        {UserName,CurrrentUserName,Pid,PidOfReceive}->
            subscribeToUser ! {UserName,CurrrentUserName,PidOfReceive,self(),Pid}
    end,
    receive
        {Message,Pid1}->
            Pid1 ! {Message},
            bufferSignIn()
    end.    
twitterStart()->
    List1 = [{"a","sample"}],
    List2=[{"UserExample",["hi"]}],
    List3=[{"KevinHart","The Greatest Comedian of all time is KevinHart."}],
    List4=[{"a",[]}],
    List5=[{"Il","Random"}],
    Map1 = maps:from_list(List1),
    Map2 = maps:from_list(List2),
    Map3= maps:from_list(List3),
    Map4=maps:from_list(List4),
    Map5=maps:from_list(List5),
    register(userregister,spawn(list_to_atom("server@HB33"),register,recieveMessage,[Map1])),
    register(receiveTweet,spawn(list_to_atom("server@HB33"),sendreceive, retrieveTweetfromUser,[Map2])),
    register(hashTagMap,spawn(list_to_atom("server@HB33"),sendreceive, mapHashTagTweet,[Map3])),
    register(subscribeToUser,spawn(list_to_atom("server@HB33"),register,userSubscriberMap,[Map4])),
    register(userProcessIdMap,spawn(list_to_atom("server@HB33"),register,userProcessIdMap,[Map5])).
tweetSend()->
    Tweet1=io:get_line("Enter Your Tweet "),
    Tweet=lists:nth(1,string:tokens(Tweet1,"\n")),
    try sendreceive:tweetSendtoServer(Tweet)
    catch 
    error:_ -> 
      io:format("User Not Signed in~n") 
    end.   
retrieveUserList()->
    spawn(register,getUsersList,[]).  
subscribe()->
    UserName1=io:get_line("Enter User You want to subscribe to"),
    UserName=lists:nth(1,string:tokens(UserName1,"\n")),
    register:subscribeToUser(UserName).
signInAndOut()->
    register:signOutUser().



