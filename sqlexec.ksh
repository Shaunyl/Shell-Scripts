#!/bin/ksh

# v1.0
# Bug: exit...

usage() {
  echo "Usage: $0 [-l sourcefile] [-f] [-n] [-h]"
  echo "  sourcefile: source file contaning scripts to be executed - defaults to ./sqlist.cfg"
  echo "  -n: enable Dry Run Mode (do nothing) - disabled by default"
  echo "  -f: force the execution without prompt for confirmation"
  echo "Example: ./sqlexec.ksh source.cfg"
  exit 1
}

# Handle options
while getopts "l:hnf" opt; do
  case $opt in
  	h)
	  usage ;;
    f) FORCE=y ;;
	n) 
	  echo "DRY RUN MODE (do nothing)"
	  DRY=123
	  ;;
	l)
	  echo "Using list file [$OPTARG]"
	  LFILE=$OPTARG ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

DRY=${DRY:-2}

if [[ -z $LFILE ]]; then
    echo "Using default list file [./sqlist.cfg]"
    LFILE="./sqlist.cfg"
fi

if [[ ! -r "$LFILE" ]]; then
    echo "Cannot read input file $LFILE "
    echo
    usage
fi

export nums=$(cat $LFILE | wc -l |  tr -s '[:space:]')
export u=0

{ cat $LFILE | while read x     k
do
        export u=$(($u+1))
        if [[ $DRY -eq 2 ]]; then
                if [[ ! -r $x ]];then
                        printf "[$u/$nums]			$x			file not found or not readable!";
                        echo "Aborting.."
                        exit 2
                fi
        fi

        printf "[%d/%d]		[%s]	[%s]			Starts in " $u $nums $k $x;
        for i in 3 2 1; do
                printf "$i "
                sleep 1
        done
        printf "%s" "-> "
        sleep 1
        if [[ $DRY -eq 2 ]]; then
                if [[ -z $FORCE ]]; then
                    while true; do
                        echo "\n> Proceed? (y/N): \c"
                        read yn <&3
                        case $yn in
                            [Yy]* ) break;;
                            [Nn]* ) exit;;
                            * ) echo "Please answer yes or no.";;
                        esac
                    done
                fi
                ./exec.ksh $k $x > $x.out 2>&1
                if [[ $? -gt 0 ]]; then
                        echo "  Internal Error: please check $x.out"
                        echo "Aborting.."
                        exit 3
                fi
                sleep 1
                e=$(cat $x.out | egrep 'ORA-|SP2-')
                if [[ -n $e ]]; then
                        echo "		Error: $e"
                        echo "Aborting.."
                        exit 4
                else
                        printf "		OK\n"
                fi
                sleep 1
        else
                printf "		DRY RUN\n"
        fi
done; } 3<&0

exit 0
