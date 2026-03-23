import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sqlight

import cats_schema_generated/migrate
import cats_schema_generated/resource.{type Cat}
import cats_schema_generated/structure.{
  type CatField,
  type CatRow,
  type CatsDb,
  type FilterableCat,
  type NumRefOrValue,
  type StringRefOrValue,
  AgeInt,
  AgeField,
  CatsDb,
  CreatedAtInt,
  CreatedAtField,
  DeletedAtInt,
  DeletedAtField,
  FilterableCat,
  IdInt,
  IdField,
  NameString,
  NameField,
  NumRef,
  NumValue,
  StringRef,
  StringValue,
  UpdatedAtInt,
  UpdatedAtField,
  cat_row_decoder,
}
import gen/filter

pub type Filter = fn(FilterableCat) -> filter.BoolExpr(NumRefOrValue, StringRefOrValue)

pub fn filter_arg(
  nullable_filter: Option(Filter),
  sort: Option(filter.SortOrder(CatField)),
) -> filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField) {
  case nullable_filter {
    Some(f) -> filter.FilterArg(filter: f, sort: sort)
    None -> filter.NoFilter(sort: sort)
  }
}

fn filterable_refs() -> FilterableCat {
  FilterableCat(
    name: StringRef(NameString),
    age: NumRef(AgeInt),
    id: NumRef(IdInt),
    created_at: NumRef(CreatedAtInt),
    updated_at: NumRef(UpdatedAtInt),
    deleted_at: NumRef(DeletedAtInt),
  )
}

fn num_operand_sql(op: NumRefOrValue) -> #(String, List(sqlight.Value)) {
  case op {
    NumRef(AgeInt) -> #("age", [])
    NumRef(IdInt) -> #("id", [])
    NumRef(CreatedAtInt) -> #("created_at", [])
    NumRef(UpdatedAtInt) -> #("updated_at", [])
    NumRef(DeletedAtInt) -> #("deleted_at", [])
    NumValue(value: v) -> #("?", [sqlight.int(v)])
  }
}

fn string_operand_sql(op: StringRefOrValue) -> #(String, List(sqlight.Value)) {
  case op {
    StringRef(NameString) -> #("name", [])
    StringValue(value: s) -> #("?", [sqlight.text(s)])
  }
}

fn bool_expr_sql(
  expr: filter.BoolExpr(NumRefOrValue, StringRefOrValue),
) -> #(String, List(sqlight.Value)) {
  case expr {
    filter.LiteralTrue -> #("1 = 1", [])
    filter.LiteralFalse -> #("1 = 0", [])
    filter.Not(inner) -> {
      let #(s, p) = bool_expr_sql(inner)
      #("not (" <> s <> ")", p)
    }
    filter.And(left, right) -> {
      let #(ls, lp) = bool_expr_sql(left)
      let #(rs, rp) = bool_expr_sql(right)
      #("(" <> ls <> ") and (" <> rs <> ")", list.append(lp, rp))
    }
    filter.Or(left, right) -> {
      let #(ls, lp) = bool_expr_sql(left)
      let #(rs, rp) = bool_expr_sql(right)
      #("(" <> ls <> ") or (" <> rs <> ")", list.append(lp, rp))
    }
    filter.Gt(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " > " <> rs, list.append(lp, rp))
    }
    filter.Eq(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " = " <> rs, list.append(lp, rp))
    }
    filter.Ne(left, right) -> {
      let #(ls, lp) = num_operand_sql(left)
      let #(rs, rp) = num_operand_sql(right)
      #(ls <> " <> " <> rs, list.append(lp, rp))
    }
    filter.NotContains(left, right) -> {
      let #(ls, lp) = string_operand_sql(left)
      let #(rs, rp) = string_operand_sql(right)
      #("instr(" <> ls <> ", " <> rs <> ") = 0", list.append(lp, rp))
    }
  }
}

fn cat_field_sql(field: CatField) -> String {
  case field {
    NameField -> "name"
    AgeField -> "age"
    IdField -> "id"
    CreatedAtField -> "created_at"
    UpdatedAtField -> "updated_at"
    DeletedAtField -> "deleted_at"
  }
}

fn sort_clause(sort: Option(filter.SortOrder(CatField))) -> String {
  case sort {
    None -> ""
    Some(filter.Asc(f)) -> " order by " <> cat_field_sql(f) <> " asc"
    Some(filter.Desc(f)) -> " order by " <> cat_field_sql(f) <> " desc"
  }
}

fn read_many_sql(
  arg: filter.FilterArg(FilterableCat, NumRefOrValue, StringRefOrValue, CatField),
) -> #(String, List(sqlight.Value)) {
  let base =
    "select id, created_at, updated_at, deleted_at, name, age from cats where deleted_at is null and "
  case arg {
    filter.NoFilter(sort: s) -> #(base <> "1 = 1" <> sort_clause(s), [])
    filter.FilterArg(filter: f, sort: s) -> {
      let #(cond, params) = bool_expr_sql(f(filterable_refs()))
      #(base <> "(" <> cond <> ")" <> sort_clause(s), params)
    }
  }
}

fn has_identity(cat: Cat) -> Bool {
  case cat.name {
    Some(_) -> True
    None -> False
  }
}

fn missing_identity_error(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  case sqlight.query(
    "this is not valid sql -- at least one identity field must be provided for upsert",
    on: conn,
    with: [],
    expecting: decode.success(Nil),
  ) {
    Error(err) -> Error(err)
    Ok(_) -> Ok(Nil)
  }
}

pub fn cats(conn: sqlight.Connection) -> CatsDb {
  CatsDb(
    migrate: fn() { migrate.migrate_idemptotent(conn) },
    upsert_one: fn(cat: Cat) -> Result(CatRow, sqlight.Error) {
      use _ <- result.try(case has_identity(cat) {
        True -> Ok(Nil)
        False -> missing_identity_error(conn)
      })
      let stamp = 1
      case cat.name {
        Some(name_str) -> {
          let upsert =
            "insert into cats (name, age, created_at, updated_at, deleted_at) values (?, ?, ?, ?, null) on conflict(name) do update set age = excluded.age, updated_at = excluded.updated_at, deleted_at = null"
          use _ <- result.try(sqlight.query(
            upsert,
            on: conn,
            with: [
              sqlight.text(name_str),
              sqlight.nullable(sqlight.int, cat.age),
              sqlight.int(stamp),
              sqlight.int(stamp),
            ],
            expecting: decode.success(Nil),
          ))
          sqlight.query(
            "select id, created_at, updated_at, deleted_at, name, age from cats where name = ? and deleted_at is null limit 1",
            on: conn,
            with: [sqlight.text(name_str)],
            expecting: cat_row_decoder(),
          )
          |> result.map(fn(rows) {
            let assert [r] = rows
            r
          })
        }
        None -> {
          use _ <- result.try(missing_identity_error(conn))
          // Unreachable: missing_identity_error always returns Error.
          sqlight.query(
            "select id, created_at, updated_at, deleted_at, name, age from cats where id = -1",
            on: conn,
            with: [],
            expecting: cat_row_decoder(),
          )
          |> result.map(fn(rows) {
            let assert [r] = rows
            r
          })
        }
      }
    },
    upsert_many: fn(rows: List(Cat)) -> Result(List(CatRow), sqlight.Error) {
      list.try_map(over: rows, with: fn(c) { cats(conn).upsert_one(c) })
    },
    read_one: fn(id: Int) -> Result(Option(CatRow), sqlight.Error) {
      use rows <- result.try(sqlight.query(
        "select id, created_at, updated_at, deleted_at, name, age from cats where id = ? and deleted_at is null",
        on: conn,
        with: [sqlight.int(id)],
        expecting: cat_row_decoder(),
      ))
      case rows {
        [row, ..] -> Ok(Some(row))
        [] -> Ok(None)
      }
    },
    read_many: fn(arg: filter.FilterArg(
      FilterableCat,
      NumRefOrValue,
      StringRefOrValue,
      CatField,
    )) -> Result(List(CatRow), sqlight.Error) {
      let #(sql, params) = read_many_sql(arg)
      sqlight.query(sql, on: conn, with: params, expecting: cat_row_decoder())
    },
    delete_one: fn(id: Int) -> Result(Nil, sqlight.Error) {
      use _ <- result.try(sqlight.query(
        "delete from cats where id = ?",
        on: conn,
        with: [sqlight.int(id)],
        expecting: decode.success(Nil),
      ))
      Ok(Nil)
    },
    delete_many: fn(ids: List(Int)) -> Result(Nil, sqlight.Error) {
      case ids {
        [] -> Ok(Nil)
        _ -> {
          let placeholders = list.map(ids, fn(_) { "?" }) |> string.join(", ")
          let sql = "delete from cats where id in (" <> placeholders <> ")"
          let args = list.map(ids, sqlight.int)
          use _ <- result.try(sqlight.query(
            sql,
            on: conn,
            with: args,
            expecting: decode.success(Nil),
          ))
          Ok(Nil)
        }
      }
    },
  )
}
