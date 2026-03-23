import gleam/option.{type Option}

import help/identity

pub type Student {
  Student(
    name: Option(String),
    email: Option(String),
    grade_level: Option(Int),
    // this is a link with attributes
    //! squeal outlink: Student -> Class with attributes
    enrollments: List(#(Class, EnrollmentAttributes)),
    // this is a link without attributes
    //! squeal outline outlink: Student -> Class without attributes
    classes: List(Class),
  )
}

pub type EnrollmentAttributes {
  EnrollmentAttributes(enrolled_at: Option(String), grade: Option(String))
}

pub type Class {
  Class(
    title: Option(String),
    subject_code: Option(String),
    //! squeal backlink: Student -> Class
    students: List(Student),
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
