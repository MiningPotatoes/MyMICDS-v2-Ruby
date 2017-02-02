# MyMICDS-v2-Ruby
This is a rewrite of [MyMICDS-v2](https://github.com/michaelgira23/MyMICDS-v2), but in Ruby instead of JavaScript.

## Setup

### Dependencies
Before you can run this repository, you have to run `bundle install` to install all the required dependencies.

### Config
You also have to set up a local config file on every machine. This file contains all the credentials and such that are required for proper operation. Use `config.example.yml` as a model to create a `config.yml` with all the information properly filled out. This will not be committed, so don't worry.

## Running
Just run the `rackup` command in this directory (provided you have `rack` installed) to start the server.

## Style
- If a method queries the database *at all*, `yield` to a block instead of `return`ing a value.
- When `yield`ing, make sure to add a `block_given?` clause to deal with whatever happens if a block isn't given.
- Write as few `raise` statements as possible.
  - A good way to do this is to reuse statements made in other methods that are being called.

## TODO
- `rdoc` file documentation
- [RAML](http://raml.org/) API documentation
- everything else