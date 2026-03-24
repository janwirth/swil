import gleam/dynamic/decode
import gleam/option.{type Option}

import dog_db/resource.{type DogForUpsert}
import dog_schema.{type Dog, Dog}
import help/filter
import sqlight

pub type FilterableDog {
  FilterableDog(
    name: StringRefOrValue,
    age: NumRefOrValue,
    is_neutered: NumRefOrValue,
    id: NumRefOrValue,
    created_at: NumRefOrValue,
    updated_at: NumRefOrValue,
    deleted_at: NumRefOrValue,
  )
}

pub type StringRefOrValue {
  StringRef(ref: StringDogField)
  StringValue(value: String)
}

pub type NumRefOrValue {
  NumRef(ref: NumDogField)
  NumValue(value: Int)
}

pub type NumDogField {
  AgeInt
  IsNeuteredInt
  IdInt
  CreatedAtInt
  UpdatedAtInt
  DeletedAtInt
}

pub type StringDogField {
  NameString
}

pub type DogField {
  NameField
  AgeField
  IsNeuteredField
  IdField
  CreatedAtField
  UpdatedAtField
  DeletedAtField
}

pub type DogRow {
  DogRow(
    value: Dog,
    id: Int,
    created_at: Int,
    updated_at: Int,
    deleted_at: Option(Int),
  )
}

pub type DogsDb {
  DogsDb(
    migrate: fn() -> Result(Nil, sqlight.Error),
    upsert_one: fn(DogForUpsert) -> Result(DogRow, sqlight.Error),
    upsert_many: fn(List(DogForUpsert)) -> Result(List(DogRow), sqlight.Error),
    update_one: fn(Int, Dog) -> Result(Option(DogRow), sqlight.Error),
    update_many: fn(List(#(Int, Dog)))
    ->
    Result(List(Option(DogRow)), sqlight.Error),
    read_one: fn(Int) -> Result(Option(DogRow), sqlight.Error),
    read_many: fn(
      filter.FilterArg(FilterableDog, NumRefOrValue, StringRefOrValue, DogField),
    )
    ->
    Result(List(DogRow), sqlight.Error),
    delete_one: fn(Int) -> Result(Nil, sqlight.Error),
    delete_many: fn(List(Int)) -> Result(Nil, sqlight.Error),
  )
}

pub fn dog_row_decoder() -> decode.Decoder(DogRow) {
  use id <- decode.field(0, decode.int)
  use created_at <- decode.field(1, decode.int)
  use updated_at <- decode.field(2, decode.int)
  use deleted_at <- decode.field(3, decode.optional(decode.int))
  use name <- decode.field(4, decode.optional(decode.string))
  use age <- decode.field(5, decode.optional(decode.int))
  use is_neutered <- decode.field(
    6,
    decode.optional(decode.map(decode.int, fn(i) { i != 0 })),
  )
  decode.success(DogRow(
    value: Dog(name: name, age: age, is_neutered: is_neutered),
    id:,
    created_at:,
    updated_at:,
    deleted_at:,
  ))
}
