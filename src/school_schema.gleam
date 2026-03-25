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
    
    //! squeal outlink
    best_friend: Option(Student),

    //! squeal backlink .best_friend
    best_fiend_of: List(Student),

    friends_book: Scalar(FriendBook)
  )
}

pub type EnrollmentAttributes {
  EnrollmentAttributes(enrolled_at: Option(String), grade: Option(String))
}

pub type Class {
  Class(
    title: Option(String),
    subject_code: Option(String),
    // any multi ref should prompt the user
    //! squeal backlink: Student -> Class
    students: List(Student),

  )
}


pub type FriendBook {
  FriendBook(
    friends: List(Student),
  )
}

pub type Scalar(t) {
  Scalar(kind: t)
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


