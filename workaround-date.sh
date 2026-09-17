#!/bin/sh

# This script is a workaround for upstream issue https://github.com/openemr/openemr/issues/13894.
# The Polarix Containers image does not include Python, and thus Bash raises arithmetic errors.
#
# The workaround implemented here is to return an error code whenever `date +%s.%N` is invoked. In
# all other cases, `/bin/date` will be invoked as normal. This script implements the logic and is
# installed at `/usr/local/bin/date`.

if [ "$1" = '+%s.%N' ]; then
	exit 1;
else
	/bin/date "$@"
fi
