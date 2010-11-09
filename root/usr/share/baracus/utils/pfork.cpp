#include <iostream>
#include <unistd.h> 	/* for fork */
#include <sys/types.h> 	/* for pid_t */
#include <sys/wait.h> 	/* for wait */
#include <stdlib.h>

#include <sys/stat.h>

using namespace std;

void daemonize( int argc, char* argv[])
{
	int i,lfp;
	string command = "";
	
	for( int aCount = 1; aCount < argc; aCount++)
	{
		command.append( argv[aCount]);
		command.append( " ");
	}

	if(getppid()==1)
	{
		return;
	} 
	
	i=fork();
	
	if (i>0)
	{
		return;
	} 
	

	// child (daemon) continues - obtain a new process group - close all descriptors
	setsid(); 							

	for (i=getdtablesize();i>=0;--i)
	{
		close(i); 							
	}

    /* Change the current working directory.  This prevents the current
       directory from being locked; hence not being able to remove it. */
    if ((chdir("/")) < 0) {
        exit(EXIT_FAILURE);
    }

    /* Redirect standard files to /dev/null */
    freopen( "/dev/null", "r", stdin);
    freopen( "/dev/null", "w", stdout);
    freopen( "/dev/null", "w", stderr);

	system( command.c_str());

	return;
}

int main(int argc, char* argv[])
{

	//cout << "Content-type: text/html\n\n" << endl;
	
	//cout << "\nProcessing.." << endl;

	daemonize( argc, argv);
	return 0;
}