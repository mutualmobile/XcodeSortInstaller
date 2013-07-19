echo "Checking if project file sort is necessary..."

PROJECT_FILE_NAME="$PROJECT_FILE_PATH/project.pbxproj"

sort_files_maybe(){
	echo "Checking for last project file sort time..."

	LAST_RUN_FILE_PATH="$SRCROOT/project_sort_last_run"

	if [ -e "$LAST_RUN_FILE_PATH" ]; then
		echo "Last sort file exists at path $LAST_RUN_FILE_PATH"
	else
		echo "First time run detected. Touching file $LAST_RUN_FILE_PATH"
		touch "$LAST_RUN_FILE_PATH"
	fi

	if [ $LAST_RUN_FILE_PATH -ot $PROJECT_FILE_PATH ]; then
		echo "Last run file is older than last project file sort. Executing sort..."
		touch "$LAST_RUN_FILE_PATH"

		echo "Sorting project file..."
		perl -w "$SRCROOT/sort-Xcode-project-file.pl" $PROJECT_FILE_NAME

	else
		echo "Last sort is newer than project file timestamp. No need to sort at this time."
	fi
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
