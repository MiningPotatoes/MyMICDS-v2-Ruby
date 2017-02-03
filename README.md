# MyMICDS-v2-Ruby
This is a rewrite of [MyMICDS-v2](https://github.com/michaelgira23/MyMICDS-v2), but in Ruby instead of JavaScript.

## Setup

### Dependencies
Before you can run this repository, you have to run `bundle install` to install all the required dependencies. **However**, if you are not using MRI (i.e. you're on Windows), you have to manually install bcrypt with `gem install bcrypt --platform=ruby`.

### Config
You also have to set up a local config file on every machine. This file contains all the credentials and such that are required for proper operation. Use `config.example.yml` as a model to create a `config.yml` with all the information properly filled out. This will not be committed, so don't worry.

## Running
Just run the `rackup` command in this directory (provided you have `rack` installed) to start the server.

## TODO
- `rdoc` file documentation
- [RAML](http://raml.org/) API documentation
- everything else