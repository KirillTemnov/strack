# Project/bug tracking system

<img src="http://farm6.static.flickr.com/5298/5476842202_761faf7d5e_b.jpg" />


## Getting started

Installation:
    npm install strack

After install check config:

    # if you use git, user and email already set
    strack config
    strack config user YourName
    strack config email YourEmail

## Work with strack

cd to any project directory and type:
    strack log


Add new task(s):

    strack add @todo Learn how strack works
    strack add @bug It can be useful for bug tracking

Watch log and grep for text in tracker:

    # show log
    strack log
    # show todo's
    strack log @todo        
    # show bugs
    strack log @bug
    # show task, matching "track" word
    strack log track

Update state of a task:
    # get first 2-4 id numbers from task
    strack state id @done

Remove task
    # get first 2-4 id numbers from task
    strack remove id

## Getting help
   
   strack help

   strack help command
