# MyMICDS-v2-Ruby
This is a rewrite of [MyMICDS-v2](https://github.com/michaelgira23/MyMICDS-v2), but in Ruby instead of JavaScript.

## Setup

### Dependencies
Before you can run this repository, you have to run `bundle install` to install all the required dependencies. **However**, if you are not using MRI (i.e. you're on Windows), you have to manually install bcrypt with `gem install bcrypt --platform=ruby`.

### Config
You also have to set up a local config file on every machine. This file contains all the credentials and such that are required for proper operation. Use `config.example.yaml` as a model to create a `config.yaml` with all the information properly filled out. This will not be committed, so don't worry.

## Running
Just run the `rackup` command in this directory to start the server. By default, it runs on port 1420, but this can be changed with the `-p` flag.

## Wait, why are you throwing errors if a user, teacher, etc. isn't found?
If you take a look at the `routes` files, *all* the errors are caught and the message is displayed. If I did something like returning `false`, I would have to add special clauses. Besides, if you look at the JavaScript API, an error is placed in the callback anyway, so it's still relatively consistent.

## TODO
- `rdoc` file documentation
- [RAML](http://raml.org/) API documentation
- everything else