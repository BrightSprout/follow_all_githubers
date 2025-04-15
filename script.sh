#!/bin/bash

since_id=$(cat since.txt)
users_failed_follow=()
followed_users=()
users=""

get_users() {
    url="https://api.github.com/users?since=$since_id"
    response=$(curl -s -w "%{http_code}" -o ./tmp/users.txt "$url")
    http_code="${response: -3}"

    if [ "$http_code" -eq 200 ]; then
        body=$(cat ./tmp/users.txt)
        users=$(echo "$body" | jq -r '.[] | @base64')
    else
        echo "Fetching github users failed!"
    fi
}

follow_user() {
   url="https://api.github.com/user/following/${1}"
   auth_key=$(cat auth_key.txt)

   response=$(curl -s -w "%{http_code}" \
   -L -X PUT \
   -H "Accept: application/vnd.github+json" \
   -H "Authorization: Bearer $auth_key" \
   -H "X-GitHub-Api-Version: 2022-11-28" \
   "$url")

   http_code="${response: -3}"

   if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 204 ]; then
       followed_users+=("${1}")
       echo "Followed: \"${1}\""
   else 
       users_failed_follow+=("${1}")
       echo "Failed to follow: \"${1}\""
   fi
}

clean_up() {
    # update the last since_id
    echo "$since_id" > since.txt
        
    # store the users that we haven't able to follow
    IFS=" "
    users_failed_follow_str="${users_failed_follow[*]}"
    unset IFS
    
    echo "$users_failed_follow_str" >> users_failed_follow.txt
    
    # store the users we have followed
    IFS=" "
    users_failed_follow_str="${followed_users[*]}"
    unset IFS
    
    echo "$users_failed_follow_str" >> users_followed.txt
}

trap clean_up EXIT

while true; do
    # retrieve list of users
    get_users
    
    # loop through array of users encoded in base64
    for user in $users; do
       # decode the property of json in base64
       _jq() {
           echo "$user" | base64 --decode | jq -r ${1}
       }
    
      username=$(_jq '.login')
      
      # follow the user with given username
      follow_user "$username"

      since_id=$(_jq '.id')
    done
done
