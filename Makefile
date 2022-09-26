PLATFORM ?= $(shell \
   ( [[ $(shell hostname -s) =~ ^cheyenne*[0-9] ]] && echo cheyenne ;) \
|| ( [[ $(shell hostname -s) =~     ^gaea*[0-9] ]] && echo gaea     ;) \
|| ( [[ $(shell hostname -s) =~      ^hfe*[0-9] ]] && echo hera     ;) \
|| ( [[ $(shell hostname -s) =~      ^tfe*[0-9] ]] && echo jet      ;) \
|| ( [[ $(shell hostname -s) =~       ^fe*[0-9] ]] && echo jet      ;) \
|| ( [[ $(shell hostname -s) =~         ^Orion* ]] && echo orion    ;) \
)
#PLATFORM ?= $(shell hostname -s)
COMPILER ?= intel

default: usage

env:
	hostname -a || hostname -f || hostname -s
	@echo "PLATFORM=${PLATFORM}"
	@echo "COMPILER=${COMPILER}"

usage: env
	@echo "Usage: PLATFORM=<platform> [ COMPILER=<compiler> ] make [ <rule> ... ]"
	@echo "        platform = cheyenne | gaea | hera | jet | orion | ... "
	@echo "        compiler = intel | gnu "
	@echo "        rule = clean | build | env | show | usage | default "
	@echo "             = clean-subs | revert | reset | status "

build: env
	./manage_externals/checkout_externals
	./devbuild.sh --platform=${PLATFORM} --compiler=${COMPILER}

clean:
	rm -rf build
	rm -rf bin
	rm -rf share
	rm -rf include
	rm -f lib/*.a lib/cmake/*/*.cmake
	${MAKE} show
	@echo "... maybe also try 'make clean-subs'"

show:;git add --dry-run . 2>/dev/null | cut -d\' -f2
	${MAKE} status

subs := $(shell find . -name .git -type d | sed 's|/.git||g' )

status:;git status
	-@for sub in ${subs} ; do [[ $$sub != "." ]] && ( set -x ; git -C $$sub status ); done
	
clean-subs: clean
	-@for sub in ${subs} ; do [[ $$sub != "." ]] && ( set -x ; rm -rf $$sub ); done

revert: clean; git clean -dfx                  # remove non-committed stuff from work-tree
	${MAKE} show

reset: clean-subs; git reset --hard                # update work-tree
	${MAKE} revert
