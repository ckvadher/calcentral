require 'spec_helper'

describe Canvas::CanvasRosters do

  let(:teacher_login_id) { rand(99999).to_s }
  let(:course_id) { rand(99999) }
  let(:a_section_id) { rand(99999) }
  let(:a_section_ccn) { rand(999).to_s }
  let(:a_section_sis_id) { "SEC:2013-C-#{a_section_ccn}" }
  let(:b_section_id) { rand(99999) }
  let(:b_section_ccn) { rand(999).to_s }
  let(:b_section_sis_id) { "SEC:2013-C-#{b_section_ccn}" }
  let(:enrolled_student_canvas_id) { rand(99999) }
  let(:enrolled_student_login_id) { rand(99999).to_s }
  let(:enrolled_student_student_id) { rand(99999).to_s }
  let(:waitlisted_student_canvas_id) { rand(99999) }
  let(:waitlisted_student_login_id) { rand(99999).to_s }
  let(:waitlisted_student_student_id) { rand(99999).to_s }
  let(:unofficial_student_canvas_id) { rand(99999) }
  let(:unofficial_student_login_id) { rand(99999).to_s }

  context 'when returning rosters feed' do
    let(:linked_section_id) { rand(99999) }
    let(:linked_section_ccn) { rand(999).to_s }
    let(:linked_section_sis_id) { "SEC:2013-C-#{linked_section_ccn}" }
    let(:unlinked_section_id) { rand(99999) }
    let(:official_student_in_canvas_id) { rand(99999) }
    let(:official_student_in_canvas_login_id) { rand(99999).to_s }
    let(:official_student_in_canvas_student_id) { rand(99999).to_s }
    let(:unofficial_student_in_canvas_id) { rand(99999) }
    let(:unofficial_student_in_canvas_login_id) { rand(99999).to_s }
    let(:official_student_not_in_canvas_login_id) { rand(99999).to_s }
    let(:official_student_not_in_canvas_student_id) { rand(99999) }

    before do
      stub_teacher_status(teacher_login_id, course_id)
      allow_any_instance_of(Canvas::CourseStudents).to receive(:full_students_list).and_return(
        [
          {
            'id' => official_student_in_canvas_id,
            'login_id' => official_student_in_canvas_login_id,
            'enrollments' => [
              {
                'course_section_id' => unlinked_section_id,
                'enrollment_state' => 'active',
                'role' => 'StudentEnrollment',
                'html_url' => "https://example.com/courses/#{course_id}/users/#{official_student_in_canvas_id}"
              },
              {
                'course_section_id' => linked_section_id,
                'enrollment_state' => 'active',
                'role' => 'StudentEnrollment',
                'html_url' => "https://example.com/courses/#{course_id}/users/#{official_student_in_canvas_id}"
              }
            ]
          },
          {
            'id' => unofficial_student_in_canvas_id,
            'login_id' => unofficial_student_in_canvas_login_id,
            'enrollments' => [
              {
                'course_section_id' => linked_section_id,
                'enrollment_state' => 'active',
                'role' => 'StudentEnrollment',
                'html_url' => "https://example.com/courses/#{course_id}/users/#{unofficial_student_in_canvas_id}"
              }
            ]
          }
        ]
      )
      allow(Canvas::CourseSections).to receive(:new).with({course_id: course_id}).and_return(
        stub_proxy(:sections_list, [
          {
            course_id: course_id,
            id: linked_section_id,
            name: 'An Official Section',
            sis_section_id: linked_section_sis_id
          },
          {
            course_id: course_id,
            id: unlinked_section_id,
            name: 'An Unofficial Section'
          }
        ])
      )
      allow(CampusOracle::Queries).to receive(:get_enrolled_students).with(linked_section_ccn, '2013', 'C').and_return(
        [
          {
            'ldap_uid' => official_student_in_canvas_login_id,
            'enroll_status' => 'E',
            'student_id' => official_student_in_canvas_student_id,
            'first_name' => "Thurston",
            'last_name' => "Howell #{official_student_in_canvas_login_id}",
            'student_email_address' => "#{official_student_in_canvas_login_id}@example.com"
          },
          {
            'ldap_uid' => official_student_not_in_canvas_login_id,
            'enroll_status' => 'E',
            'student_id' => official_student_not_in_canvas_student_id,
            'first_name' => 'Clarence',
            'last_name' => "Williams #{official_student_not_in_canvas_login_id}",
            'student_email_address' => "#{official_student_in_canvas_login_id}@example.com"
          }
        ]
      )
    end

    it 'should return a list of officially enrolled students for a unlinked Canvas course site' do
      model = Canvas::CanvasRosters.new(teacher_login_id, course_id: course_id)
      feed = model.get_feed
      expect(feed[:canvas_course][:id]).to eq course_id
      expect(feed[:sections].length).to eq 2
      expect(feed[:students].length).to eq 1
      student = feed[:students][0]
      expect(student[:id]).to eq official_student_in_canvas_id
      expect(student[:student_id]).to eq official_student_in_canvas_student_id
      expect(student[:first_name].blank?).to be_falsey
      expect(student[:last_name].blank?).to be_falsey
      expect(student[:email].blank?).to be_falsey
      expect(student[:sections].length).to eq 2
      expect(student[:section_ccns].length).to eq 2
      expect(student[:profile_url].blank?).to be_falsey
    end
  end

  # A course-enabled LTI tool will be enabled even when a course site has no
  # SIS ID or no associated campus sections. Only students who are officially
  # enrolled in an associated campus section should appear in the roster.
  it "should return an empty list for an unlinked Canvas course site" do
    stub_teacher_status(teacher_login_id, course_id)
    section_id = rand(99999)
    Canvas::CourseStudents.any_instance.stub(:full_students_list).and_return(
      [
        {
          'id' => 1234,
          'login_id' => 4321,
          'enrollments' => [
            {
              'course_section_id' => section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        }
      ]
    )
    Canvas::CourseSections.stub(:new).with({course_id: course_id}).and_return(
      stub_proxy(:sections_list, [
        {
          course_id: course_id,
          id: section_id,
          name: 'not-an-official-section'
        }
      ])
    )
    model = Canvas::CanvasRosters.new(teacher_login_id, course_id: course_id)
    feed = model.get_feed
    feed[:canvas_course][:id].should == course_id
    feed[:sections].length.should == 1
    feed[:sections][0][:id].should == section_id
    feed[:sections][0][:name].should == 'not-an-official-section'
    feed[:sections][0][:sis_id].should be_nil
    feed[:students].empty?.should be_truthy
  end

  it "should show official photo links for students who are not waitlisted in all sections" do
    stub_teacher_status(teacher_login_id, course_id)
    Canvas::CourseStudents.any_instance.stub(:full_students_list).and_return(
      [
        {
          'id' => enrolled_student_canvas_id,
          'login_id' => enrolled_student_login_id,
          'enrollments' => [
            {
              'course_section_id' => a_section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        },
        {
          'id' => waitlisted_student_canvas_id,
          'login_id' => waitlisted_student_login_id,
          'enrollments' => [
            {
              'course_section_id' => a_section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        }
      ]
    )
    Canvas::CourseSections.stub(:new).with({course_id: course_id}).and_return(
      stub_proxy(:sections_list, [
        {
          course_id: course_id,
          id: a_section_id,
          name: 'An Official Section',
          sis_section_id: a_section_sis_id
        },
        {
          course_id: course_id,
          id: b_section_id,
          name: 'Another Official Section',
          sis_section_id: b_section_sis_id
        }
      ])
    )
    # A student may be waitlisted in a secondary section but enrolled in a primary section.
    CampusOracle::Queries.stub(:get_enrolled_students).with(a_section_ccn, '2013', 'C').and_return(
      [
        {
          'ldap_uid' => enrolled_student_login_id,
          'enroll_status' => 'W',
          'student_id' => enrolled_student_student_id
        },
        {
          'ldap_uid' => waitlisted_student_login_id,
          'enroll_status' => 'W',
          'student_id' => waitlisted_student_student_id
        }
      ]
    )
    CampusOracle::Queries.stub(:get_enrolled_students).with(b_section_ccn, '2013', 'C').and_return(
      [
        {
          'ldap_uid' => enrolled_student_login_id,
          'enroll_status' => 'E',
          'student_id' => enrolled_student_student_id
        },
        {
          'ldap_uid' => waitlisted_student_login_id,
          'enroll_status' => 'W',
          'student_id' => waitlisted_student_student_id
        }
      ]
    )
    model = Canvas::CanvasRosters.new(teacher_login_id, course_id: course_id)
    feed = model.get_feed
    feed[:sections].length.should == 2
    feed[:students].length.should == 2
    feed[:students].index {|student| student[:id] == waitlisted_student_canvas_id &&
        student[:photo].nil?
    }.should_not be_nil
  end

  it "should only download photo data for officially fully enrolled students" do
    stub_teacher_status(teacher_login_id, course_id)
    Canvas::CourseStudents.any_instance.stub(:full_students_list).and_return(
      [
        {
          'id' => enrolled_student_canvas_id,
          'login_id' => enrolled_student_login_id,
          'enrollments' => [
            {
              'course_section_id' => a_section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        },
        {
          'id' => waitlisted_student_canvas_id,
          'login_id' => waitlisted_student_login_id,
          'enrollments' => [
            {
              'course_section_id' => a_section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        },
        {
          'id' => unofficial_student_canvas_id,
          'login_id' => unofficial_student_login_id,
          'enrollments' => [
            {
              'course_section_id' => a_section_id,
              "enrollment_state" => "active",
              "role" => "StudentEnrollment"
            }
          ]
        }
      ]
    )
    allow(Canvas::CourseSections).to receive(:new).with({course_id: course_id}).and_return(
      stub_proxy(:sections_list, [
        {
          course_id: course_id,
          id: a_section_id,
          name: 'An Official Section',
          sis_section_id: a_section_sis_id
        }
      ])
    )
    allow(CampusOracle::Queries).to receive(:get_enrolled_students).with(a_section_ccn, '2013', 'C').and_return(
      [
        {
          'ldap_uid' => enrolled_student_login_id,
          'enroll_status' => 'E',
          'student_id' => enrolled_student_student_id
        },
        {
          'ldap_uid' => waitlisted_student_login_id,
          'enroll_status' => 'W',
          'student_id' => waitlisted_student_student_id
        }
      ]
    )
    photo_data = rand(99999999)
    allow(CampusOracle::Queries).to receive(:get_photo).with(enrolled_student_login_id).and_return(
      {
        'bytes' => 42,
        'photo' => photo_data
      }
    )
    model = Canvas::CanvasRosters.new(teacher_login_id, course_id: course_id)
    enrolled_photo = model.photo_data_or_file(enrolled_student_canvas_id)
    expect(enrolled_photo[:data]).to eq photo_data
    expect(enrolled_photo[:size]).to eq 42
    expect(enrolled_photo[:filename]).to be_nil
    waitlisted_photo = model.photo_data_or_file(waitlisted_student_canvas_id)
    expect(waitlisted_photo).to be_nil
    unofficial_photo = model.photo_data_or_file(unofficial_student_canvas_id)
    expect(unofficial_photo).to be_nil
  end

  def stub_teacher_status(teacher_login_id, canvas_course_id)
    teaching_proxy = double()
    allow(teaching_proxy).to receive(:full_teachers_list).and_return(
      [
        {
          'id' => rand(99999),
          'login_id' => teacher_login_id
        }
      ]
    )
    allow(Canvas::CourseTeachers).to receive(:new).with(course_id: canvas_course_id).and_return(teaching_proxy)
  end

end
