import gleam/dynamic/decode
import gleam/option.{type Option}

import cat_db/resource.{type CatForUpsert}
import cat_schema.{type Cat, Cat}
import help/filter
import sqlight

pub type FilterableCat {
  FilterableCat(
    name: StringRefOrValue,
    age: NumRefOrValue,
    id: NumRefOrValue,
    created_at: NumRefOrValue,
    updated_at: NumRefOrValue,
    deleted_at: NumRefOrValue,
  )
}

pub type StringRefOrValue {
  StringRef(ref: StringCatField)
  StrVal(value: String)
}

pub type NumRefOrValue {
  NumRef(ref: NumCatField)
  IntVal(value: Int)
  FloatVal(value: Float)
}

pub type NumCatField {
  AgeInt
  IdInt
  CreatedAtInt
  UpdatedAtInt
  DeletedAtInt
}

pub type StringCatField {
  NameString
}

pub type CatField {
  NameField
  AgeField
  IdField
  CreatedAtField
  UpdatedAtField
  DeletedAtField
}

pub type CatRow {
  CatRow(
    value: Cat,
    id: Int,
    created_at: Int,
    updated_at: Int,
    deleted_at: Option(Int),
  )
}

pub type CatsDb {
  CatsDb(
    migrate: fn() -> Result(Nil, sqlight.Error),
    upsert_one: fn(CatForUpsert) -> Result(CatRow, sqlight.Error),
    upsert_many: fn(List(CatForUpsert)) -> Result(List(CatRow), sqlight.Error),
    update_one: fn(Int, Cat) -> Result(Option(CatRow), sqlight.Error),
    update_many: fn(List(#(Int, Cat)))
    ->
    Result(List(Option(CatRow)), sqlight.Error),
    read_one: fn(Int) -> Result(Option(CatRow), sqlight.Error),
    read_many: fn(
      filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField),
    )
    ->
    Result(List(CatRow), sqlight.Error),
    delete_one: fn(Int) -> Result(Nil, sqlight.Error),
    delete_many: fn(List(Int)) -> Result(Nil, sqlight.Error),
  )
}

pub fn cat_row_decoder() -> decode.Decoder(CatRow) {
  use id <- decode.field(0, decode.int)
  use created_at <- decode.field(1, decode.int)
  use updated_at <- decode.field(2, decode.int)
  use deleted_at <- decode.field(3, decode.optional(decode.int))
  use name <- decode.field(4, decode.optional(decode.string))
  use age <- decode.field(5, decode.optional(decode.int))
  decode.success(CatRow(
    value: Cat(name: name, age: age),
    id:,
    created_at:,
    updated_at:,
    deleted_at:,
  ))
}
