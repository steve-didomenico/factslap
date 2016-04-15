# factslap
A URL redirection web app

###Background
This app provides a URL redirection service. A user can create their own short name for 
a URL to be redirected to. For example "factslap.com/nytarticle" could redirect to "http://www.nytimes.com/2016/04/15/..."
Alternatively, the user can let the system select the name, which will be a base-62 alpha-number.

###Install

To install:

1. Import the ylink_basic.sql file into your MySQL database.

2. Move the YLink.pm module into an appropriate directory outside of your web directories.

3. Edit YLink.pm with your database name and password.

4. Edit index.cgi and jump.cgi with the location of the YLink.pm perl module.

5. Please the HTML files in the web directory you'd like to use. Be sure that
Apache is configured to recognize .htaccess files, this is necessary. You may need to edit
the .htaccess file to match the directory of the install.


