#!/bin/bash

usesvn=$1   # 0/1  not/using svn

if [[ $usesvn == 1 ]]; then
    svnadd="svn add" 
    svnmv="svn mv"
    svnrm="svn rm"
else
    svnadd="echo created"
    svnmv="mv"
    svnrm="rm -rf"
fi

function doit
{
    echo $*
#    eval $1
}

echo "#"
echo "# Create desired template directory structure"
echo "#"

doit "mkdir -p sles/{9.4,10.2}/{x86_64,i386}"
doit "mkdir -p sles/10.2/{x86_64,i386}/{mono,rt}"
doit "mkdir -p sles/11/{x86_64,i586}/{mono,hae}"
doit "mkdir -p opensuse/11.1/{x86_64,i586}"
doit "mkdir -p rhel/5.3/{x86_64,i386}/mrg/1.1"
doit "mkdir -p fedora/11/{x86_64,i386}"

doit "$svnadd sles opensuse rhel fedora"

echo "#"
echo "# Move files"
echo "#"

# sles-9
doit "$svnmv sles9/x86_64/* sles/9.4/x86_64/."
doit "$svnmv sles9/i586/*   sles/9.4/i386/. # correct arch"    

# sles-11
doit "$svnmv sles11/x86_64/*      sles/11/x86_64/."
doit "$svnmv sles11-MONO/x86_64/* sles/11/x86_64/mono/."
doit "$svnmv sles11-HAE/x86_64/*  sles/11/x86_64/hae/."

# sles-10
doit "$svnmv sles10/x86_64/*  sles/10.2/x86_64/."
doit "$svnmv sles10/i586/*    sles/10.2/i386/. # correct arch"  
doit "$svnmv slert10/x86_64/* sles/10.2/x86_64/rt/."
doit "$svnmv slert10/i386/*   sles/10.2/i386/rt/."

# rhel-5
doit "$svnmv rhel5/x86_64/* rhel/5.3/x86_64/."

# opensuse-11
# none

# fedora
# none

echo "#"
echo "# Done."
echo "# Please confirm relocation and remove old directories"
echo "#"
echo "$svnrm sles9"
echo "$svnrm sles11"
echo "$svnrm sles10"
echo "$svnrm rhel5"

