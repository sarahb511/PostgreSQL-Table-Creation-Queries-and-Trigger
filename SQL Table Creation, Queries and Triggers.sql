/* Table Creation - PostgreSQL
based on predetermined structure by professor*/

CREATE TABLE employers (
	id SERIAL,
	name varchar(80) NOT NULL,
	address varchar(150) NOT NULL,
	phone varchar(12) NOT NULL,
	email varchar(50) NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE students (
	id SERIAL,
	name varchar(80) NOT NULL,
	email varchar(50) NOT NULL,
	major varchar(30) NOT NULL,
	degree varchar(13) NOT NULL,
	gpa numeric(5,4),
	graduation_date date NOT NULL,
	PRIMARY KEY (id),
	CHECK(degree IN('graduate','undergraduate','visiting','certification'))
);

CREATE TABLE student_skills (
	student_id int,
	student_skill varchar(30),
	PRIMARY KEY (student_id, student_skill),
	FOREIGN KEY (student_id) REFERENCES students(id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE
);

CREATE TABLE jobs (
	id SERIAL,
	emp_id int NOT NULL,
	title varchar(50) NOT NULL,
	start_date date NOT NULL,
	post_date timestamp,
	min_gpa numeric(5,4) NOT NULL,
	salary int NOT NULL,
	description text NOT NULL,
	PRIMARY KEY (id),
	FOREIGN KEY (emp_id) REFERENCES employers(id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE,
	CHECK(salary >= 0)
);

CREATE TABLE job_skills (
	job_id int,
	job_skill varchar(30),
	PRIMARY KEY (job_id, job_skill),
	FOREIGN KEY (job_id) REFERENCES jobs(id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE
);

CREATE TABLE applications (
	student_id int,
	job_id int,
	date_submitted timestamp NOT NULL,
	PRIMARY KEY (student_id, job_id),
	FOREIGN KEY (student_id) REFERENCES students(id) 
		ON UPDATE CASCADE,
	FOREIGN KEY (job_id) REFERENCES jobs(id)  
		ON UPDATE CASCADE
);

CREATE TABLE interviews (
	job_id int,
	student_id int,
	interview_date timestamp NOT NULL,
	offer_made varchar(14),
	PRIMARY KEY (job_id, student_id),
	FOREIGN KEY (job_id) REFERENCES jobs(id) 
		ON UPDATE CASCADE,
	FOREIGN KEY (student_id) REFERENCES students(id) 
		ON UPDATE CASCADE,
	CHECK(offer_made IN('no offer','offer accepted','offer rejected','offer pending'))
);




/*Provide the SQL statement that returns the job id, employer name, job name,
 * and post date/time of all job listings that a student named 'Louise Belcher'
 * may be qualified for*/
 
SELECT DISTINCT j.id as jobID,e.name,j.title,j.post_date
FROM jobs as j, employers as e, job_skills as js
WHERE j.emp_id = e.id AND jobID = js.job_id AND 
	j.min_gpa<= (SELECT gpa FROM students
				WHERE name = 'Louise Belcher') AND
	js.job_skill IN (SELECT ss.student_skill FROM students AS s,student_skills as ss 
					WHERE s.id = ss.student_id AND s.name = 'Louise Belcher');

					
					
					
/*Provide the SQL statement that creates a view called "ny_jobs". This
 * view, when called, must return the job id, company name, and job name of any
 * job posted by a company in New York.
 
 * Demonstrate how the view may be used to further limit results to jobs posted
 * in September 2019.*/
 
CREATE VIEW ny_jobs AS
SELECT j.id as jobID, e.name, j.title
FROM employers as e, jobs as j
WHERE e.id = j.emp_id AND
	e.phone LIKE ANY (ARRAY ['212%','646%','718%']);
	
SELECT * FROM ny_jobs
WHERE id IN (SELECT id FROM jobs
				WHERE post_date BETWEEN '2019-09-01 00:00:00' AND '2019-09-30 23:59:59');

				
				
				
/* Provide the SQL statement that returns the job id and job name of the job
 * that received the most applications.*/
 
SELECT j.id as jobID, j.title
FROM (SELECT job_id, count(DISTINCT student_id) as uniqueStudent,
      RANK() OVER (ORDER BY  count(DISTINCT student_id) DESC) as ranking
	  FROM applications
	  GROUP BY job_id) as countApp, jobs as j
WHERE j.id = countApp.job_id AND ranking = 1;




/*Provide the SQL statement that returns the name of any student who did more
 * than two (2) interviews without getting a single offer.*/
 
SELECT s.name 
FROM interviews as i
	JOIN students as s
	ON s.id = i.student_id
WHERE offer_made = 'no offer'
GROUP BY s.name HAVING COUNT (interview_date) > 2;




/*Provide the SQL statement that returns names of all students who are
 * experienced in both 'Python' and 'R'.*/
 
SELECT s.name as studentName
FROM (SELECT DISTINCT student_id
      FROM student_skills
      WHERE student_id IN (SELECT student_id FROM student_skills WHERE student_skill = 'Python') AND 
			student_id  IN (SELECT student_id FROM student_skills WHERE student_skill = 'R')) as skillsStudent
JOIN students as s
ON s.id = skillsStudent.student_id;




/* Provide the SQL statement that for each skill (either job skill or student
 * skill) it returns the number of jobs looking for it and the number of
 * students having it.*/
 
SELECT specificSkills.student_skill as studentSkills, 
		COUNT (DISTINCT ss.student_id) as studentNumber,
      COUNT (DISTINCT js.job_id) as jobNumber
FROM (SELECT student_skill FROM student_skills
UNION
SELECT job_skill FROM job_skills) as specificSkills
JOIN job_skills as js
ON js.job_skill = specificSkills.student_skill
JOIN student_skills as ss
ON ss.student_skill = specificSkills.student_skill
GROUP BY studentSkills;




/* Provide all necessary SQL statements that create a trigger. The trigger must
 * ensure that when a new tuple is attempted to be inserted into the
 * "interviews" table, then this tuple will only be stored if the student has
 * a gpa higher than the minimum gpa required for the job. If the student has a
 * lower gpa then the trigger should return an error.*/
 
CREATE OR REPLACE FUNCTION gpa_check()
RETURNS trigger AS
$gpa_check$
    BEGIN
        IF (SELECT j.min_gpa FROM jobs AS j
            WHERE j.id = NEW.job_id GROUP BY j.id) > 
			(SELECT s.gpa FROM students AS s
            WHERE  s.id = NEW.student_id GROUP BY  s.id) 
            THEN RAISE EXCEPTION 'The GPA of the student is too low for this job';
        END IF;
      RETURN NEW;
    END;
$gpa_check$ 
LANGUAGE plpgsql;

CREATE TRIGGER check_student_gpa BEFORE INSERT ON interviews
FOR EACH ROW
EXECUTE PROCEDURE gpa_check();