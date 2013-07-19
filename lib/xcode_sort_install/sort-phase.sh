# Copyright (c) 2013 Mutual Mobile
# 
# MIT License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Xcode sort script auto-installed using the Xcode_sort_install gem

echo "Checking if project file sort is necessary..."

PROJECT_FILE_NAME="$PROJECT_FILE_PATH/project.pbxproj"
LAST_RUN_FILE_PATH="$SRCROOT/project_sort_last_run"

sort_files_maybe(){
	echo "Checking for last project file sort time..."

	if [ -e "$LAST_RUN_FILE_PATH" ]; then
		echo "Last sort file exists at path $LAST_RUN_FILE_PATH"
		
		if [ $LAST_RUN_FILE_PATH -ot $PROJECT_FILE_PATH ]; then
			echo "Last run file is older than last project file sort. Executing sort..."

			sort_project_file
		else
			echo "Last sort is newer than project file timestamp. No need to sort at this time."
		fi
	else
		echo "First time run detected. Touching file $LAST_RUN_FILE_PATH and sorting project file"
		
		sort_project_file
	fi
}

sort_project_file(){
	touch "$LAST_RUN_FILE_PATH"
	echo "Sorting project file... $PROJECT_FILE_PATH"
	perl -w "$SRCROOT/sort-Xcode-project-file.pl" $PROJECT_FILE_NAME
}

git ls-files $PROJECT_FILE_NAME --error-unmatch 1>/dev/null 2>&1

if [ $? -eq 0 ]; then
	echo "Project file is under git control, checking source control status..."

	git diff --quiet $PROJECT_FILE_NAME 1>/dev/null 2>&1

	if [ $? -eq 1 ]; then
		echo "Project file has been modified in git, attempting sort!"
		sort_files_maybe
	else
		echo "Project file has not been modified in git, no sort needed."
	fi
else

	svn info $PROJECT_FILE_NAME 1>/dev/null 2>&1

	if [ $? -eq 0 ]; then
		echo "Project file is under svn control, checking source control status..."

		SVN_STAT=`svn status -q $PROJECT_FILE_NAME`

		if [ -n "$SVN_STAT" ]; then
			echo "Project file is modified in SVN, attempting sort!"
			sort_files_maybe
		else
			echo "Project file is not modified in SVN, no sort needed."
		fi
	fi
fi
