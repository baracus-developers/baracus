/* sparsefile.c -- copying a file to a sparse file
 *
 * Author: Eric Laroche
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * A sparse file (file with 'few' data in it) has large parts in it that
 * consist entirely of nul-bytes.
 * On some filesystems (e.g. on the ones used on Unix), the empty disk-
 * blocks that result need not be allocated and hence disk space is saved.
 * Copying such file or writing them to tape may result in loss of this
 * sparseness.  This tool intends to 'reinstall' the sparseness.
 *
 * Remarks:
 *
 *   'sparsefile' copies the standard input to the standard output while
 *   producing a sparse output file.
 *   'sparsefile' can take any input (file, device, pipe) but must write
 *   its output directly to the target file, i.e. not to a pipe.
 *
 *   Actual filesize vs. disk space:  The actual size of a file can be
 *   displayed with 'ls -l <file>', the allocated disk space with
 *   'du -sk <file>'.
 */

static char const rcsid[] =
	"@(#) $Id: sparsefile.c,v 1.2 1996/12/19 07:40:28 laroche Exp $";

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

/* sparse -- copy in to out while producing a sparse file */
int sparse( int fdin, int fdout )
{
	static char const skipbyte = '\0';

	struct stat st;
	int blocksize, skip, nbytes, eof, n, i;
	char* buf;

	/* get the blocksize used on the output media,
	 * allocate buffer
	 */
	i = fstat( fdout, &st );
	if ( i == -1 )
		return -1;
	blocksize = st.st_blksize;
	buf = malloc( blocksize );
	if ( ! buf )
		return -1;

	for ( eof = 0, skip = 0; ; )
	{
		/* read exactly one block, if necessary in multiple chunks */
		for ( nbytes = 0; nbytes < blocksize; nbytes += n )
		{
			n = read( fdin, &buf[ nbytes ], blocksize - nbytes );
			if ( n == -1 ) /* error -- don't write this block */
			{
				free( buf );
				return -1;
			}
			if ( n == 0 ) /* eof */
			{
				eof = 1;
				break;
			}
		}

		/* check if we can skip this part */
		if ( nbytes == blocksize )
		{
			/* linear search for a byte other than skipbyte */
			for ( n = 0; n < blocksize; n++ )
				if ( buf[ n ] != skipbyte )
					break;
			if ( n == blocksize )
			{
				skip += blocksize;
				continue;
			}
		}

		/* do a lseek over the skipped bytes */
		if ( skip != 0 )
		{
			/* keep one block if we got eof, i.e.
			 * don't forget to write the last block
			 */
			if ( nbytes == 0 )
			{
				/* note that the following implies using
				 * the eof flag */
				skip -= blocksize;
				nbytes += blocksize;
				/* we don't need to zero out buf since
				 * the last block was skipped, i.e. zero
				 */
			}

			i = lseek( fdout, skip, SEEK_CUR );
			if ( i == -1 ) /* error */
			{
				free( buf );
				return -1;
			}
			skip = 0;
		}

		/* write exactly nbytes */
		for ( n = 0; n < nbytes; n += i )
		{
			i = write(fdout, &buf[ n ], nbytes - n );
			if ( i == -1 || /* error */
				i == 0 ) /* can't write?? */
			{
				free( buf );
				return -1;
			}
		}

		if ( eof ) /* eof */
			break;
	}

	free( buf );
	return 0;
}

/* main -- program entry point */
int main( int argc, char** argv )
{
	/* usage */
	if ( argc != 1 )
	{
		fprintf( stderr, "usage: %s <infile >outfile\n", argv[ 0 ] );
		exit( 1 );
	}

	/* read from stdin (0), write to stdout (1) */
	if ( sparse( 0, 1 ) == -1 )
	{
		perror( argv[ 0 ] );
		exit( 1 );
	}

	return 0;
}

