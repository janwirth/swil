// ## Opinionated database

// - Simple: define types once; automatic migrations follow.
// - **Codegen:** migrations are idempotent (table/column upsert).
// - **API:** one constructor per schema name, e.g. `classes(...)`, `students(...)`.
// - **Rows:** same fields as the schema plus `created_at`, `updated_at`.
// - **CRUD:** by id; by filter; joins with typed fields (booleans, etc.).

// **Queries** — either a small builder or a typed select that transpiles to SQL:

// ```gleam
// // Predicate → SQL
// select(fn(x) { x.grade_level > 10 })

// // Field reference → SQL fragment (example name)
// lgtr(1, x.name)
// ```
import gleam/option.{type Option}

import help/identity

// inspired by ash
// RESOURCE

// never directly interact with schema
pub type Student {
  Student(
    name: Option(String),
    email: Option(String),
    grade_level: Option(Int),
  )
}

pub type EnrollmentAttributes {
  EnrollmentAttributes(enrolled_at: Option(String), grade: Option(String))
}

pub type Class {
  Class(
    title: String,
    subject_code: String,
    students: Multi(Backlink(Student, EnrollmentAttributes)),
  )
}

pub type Multi(t) {
  Multi(items: List(t))
}

pub type Backlink(t, attributes) {
  Backlink(item: t)
  BacklinkWithAttributes(item: t, attributes: attributes)
}

pub fn identities_student(student: Student) {
  [identity.Identity2(student.name, student.email)]
}

pub fn identities_class(class: Class) {
  [identity.Identity2(class.title, class.subject_code)]
}
