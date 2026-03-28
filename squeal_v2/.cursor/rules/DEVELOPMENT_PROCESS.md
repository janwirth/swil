---
globs:
alwaysApply: true
---

Development process

1. pinpoint new requirements in the generated code ({module_name}\_db) or schema
2. create a new test case for the requirement
   - parser
   - generation
   - db schema
   - e2e test
3. implement the requirement
   - parser
   - schema types
   - db migrations
   - generators

Ensure the following

1. the code is stable after generation leam run -- src/case_studies/'module_name' and then the tests pass
2. the generators do not hard-code any module specific logic but abstract over the module name
