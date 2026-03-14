# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Rails.logger.debug "Creating Users"

User.create(name: "Admin",
            email: "admin@circuitverse.org",
            password: "password",
            admin: true,
            confirmed_at: Time.now
)
users = User.create([{ name: "user1", email: "user1@circuitverse.org", password: "password" },
                     { name: "user2", email: "user2@circuitverse.org", password: "password" }])

# private,public,limited access
Rails.logger.debug "Creating Projects"
projects = Project.create([{ name: "Private",
                             author_id: users.first.id,
                             project_access_type: "Private",
                             description: "description" },
                           { name: "Public",
                             author_id: users.first.id,
                             project_access_type: "Public",
                             description: "description" },
                           { name: "Limited access",
                             author_id: users.first.id,
                             project_access_type: "Limited access",
                             description: "description" }])

# examples
Rails.logger.debug "Creating Examples"
Project.create([{ name: "Full Adder",
                  author_id: users.first.id,
                  project_datum_attributes: { data: File.read("db/examples/fullAdder.json") },
                  project_access_type: "Public",
                  description: "description" },
                { name: "SAP",
                  author_id: users.first.id,
                  project_datum_attributes: { data: File.read("db/examples/SAP.json") },
                  project_access_type: "Public",
                  description: "SAP-1 short for simple as possible computer is a 8 Bit computer. It can perform simple operations like Addition and Subtraction." },
                { name: "ALU-74LS181",
                  author_id: users.first.id,
                  project_datum_attributes: { data: File.read("db/examples/ALU-74LS181.json") },
                  project_access_type: "Public",
                  description: "description" }])

#groups
puts "Creating Groups"
group = Group.create(name: 'group1',
  primary_mentor_id: users.first.id,
)
GroupMember.create(group_id: group.id,
                   user_id: users.second.id)

# tags
Rails.logger.debug "Creating Tags"
tag = Tag.create(name: "example")
Tagging.create([{ tag_id: tag.id,
                  project_id: projects.first.id },
                { tag_id: tag.id,
                  project_id: projects.second.id },
                { tag_id: tag.id,
                  project_id: projects.third.id }])

# ============================================================
# GSoC 2026 Demo Data — Assignment Suite Features
# ============================================================
if Rails.env.development?
  puts "Seeding GSoC demo data..."

  mentor = User.first
  group  = Group.first

  if mentor && group
    # Multi-level hierarchy
    child_group = Group.find_or_create_by!(
      name: "Section A — Digital Logic",
      primary_mentor: mentor
    ) do |g|
      g.parent_group = group
    end
    puts "Created child group: #{child_group.name}"

    # Subgroup
    subgroup = Subgroup.find_or_create_by!(
      name: "Team Alpha",
      group: group
    ) do |s|
      s.max_size = 4
    end
    puts "Created subgroup: #{subgroup.name}"

    # Circuit template
    template = CircuitTemplate.find_or_create_by!(
      name: "AND Gate Lab",
      created_by: mentor
    ) do |t|
      t.description  = "Basic AND gate verification exercise"
      t.circuit_data = {
        components: [{ type: "AND", inputs: 2 }],
        inputs:     [{ name: "A" }, { name: "B" }],
        outputs:    [{ name: "Y" }]
      }
      t.public = true
    end
    puts "Created circuit template: #{template.name}"

    # Test cases on first assignment
    assignment = Assignment.first
    if assignment
      AssignmentTestCase.find_or_create_by!(
        assignment:      assignment,
        description:     "Both inputs HIGH → output HIGH"
      ) do |tc|
        tc.input_pins      = { "A" => 1, "B" => 1 }
        tc.expected_output = { "Y" => 1 }
        tc.position        = 1
      end
      AssignmentTestCase.find_or_create_by!(
        assignment:      assignment,
        description:     "Both inputs LOW → output LOW"
      ) do |tc|
        tc.input_pins      = { "A" => 0, "B" => 0 }
        tc.expected_output = { "Y" => 0 }
        tc.position        = 2
      end
      puts "Created 2 test cases on assignment: #{assignment.name}"
    end

    # Assignments
    assignment1 = Assignment.find_or_create_by!(
      name:  "AND Gate Lab",
      group: group
    ) do |a|
      a.deadline         = 4.weeks.from_now
      a.status           = "open"
      a.grading_scale    = :percent
      a.circuit_template = template
    end
    puts "Created assignment: #{assignment1.name}"

    assignment2 = Assignment.find_or_create_by!(
      name:  "OR Gate Exercise",
      group: group
    ) do |a|
      a.deadline      = 2.weeks.from_now
      a.status        = "open"
      a.grading_scale = :no_scale
    end
    puts "Created assignment: #{assignment2.name}"

    # Test cases on assignment 1
    AssignmentTestCase.find_or_create_by!(
      assignment:  assignment1,
      description: "Both inputs HIGH → output HIGH"
    ) do |tc|
      tc.input_pins      = { "A" => 1, "B" => 1 }
      tc.expected_output = { "Y" => 1 }
      tc.position        = 1
    end

    AssignmentTestCase.find_or_create_by!(
      assignment:  assignment1,
      description: "Both inputs LOW → output LOW"
    ) do |tc|
      tc.input_pins      = { "A" => 0, "B" => 0 }
      tc.expected_output = { "Y" => 0 }
      tc.position        = 2
    end

    AssignmentTestCase.find_or_create_by!(
      assignment:  assignment1,
      description: "A HIGH, B LOW → output LOW"
    ) do |tc|
      tc.input_pins      = { "A" => 1, "B" => 0 }
      tc.expected_output = { "Y" => 0 }
      tc.position        = 3
    end
    puts "Created 3 test cases on assignment: #{assignment1.name}"

    # Submission
    student = User.find_by(email: "user2@circuitverse.org")
    if student
      student_project = Project.find_or_create_by!(
        name:   "#{student.name}/#{assignment1.name}",
        author: student
      ) do |p|
        p.project_access_type = "Private"
        p.description         = "Student submission for AND Gate Lab"
        p.assignment          = assignment1
      end

      AssignmentSubmission.find_or_create_by!(
        assignment: assignment1,
        user:       student,
        project:    student_project
      ) do |s|
        s.status       = :submitted
        s.submitted_at = Time.zone.now
        s.score        = 66.67
      end
      puts "Created submission for #{student.name}"
    end

    puts "Classroom data seeded successfully!"
  else
    puts "No users or groups found — sign up at localhost:3000 first"
  end
end
