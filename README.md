# neuroplastic

[![CI](https://github.com/place-labs/neuroplastic/actions/workflows/ci.yml/badge.svg)](https://github.com/place-labs/neuroplastic/actions/workflows/ci.yml)

A module for [rethinkdb-orm](https://github.com/spider-gazelle/rethinkdb-orm).<br>
Exposes an elasticsearch query DSL that automagically resolves relations between the models.

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
    neuroplastic:
    github: place-labs/neuroplastic
```

2. Run `shards install`

## Usage

```crystal
require "neuroplastic"
class Model < RethinkORM::Base
  include Neuroplastic

  attribute name : String
  attribute age : Int32
end

# Construct a query
query = Model.elastic.query.filter({"name": "bill"})

# Dump the query object
puts query.build

# Perform search
Model.elastic.search(query)
```

## Contributing

1. [Fork it](<https://github.com/place-labs/neuroplastic/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Caspian Baska](https://github.com/Caspiano) - creator and maintainer
