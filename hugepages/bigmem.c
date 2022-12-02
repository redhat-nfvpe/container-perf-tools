/*
 * Copyright 2011, 2019 Red Hat, Inc.
 *
 * bigmem.c: a program to allocate large amounts of memory
 *
 * Changelog:
 *   * Mon Jul 15 2019 Herve Quatremain <hquatrem@redhat.com>
 *   - New function to use the huge pages through mmap() (-m program option)
 *   - New function to allocate the requested memory in one big chunk (-b)
 *   - The program now accepts a unit for the memory size (K, M, or G)
 *   * 2011 Wander Boessenkool <wander@redhat.com>
 *   - original code
 */

/* vim: ts=2 sts=2 sw=2 et si */

#define _GNU_SOURCE

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/mman.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define MEBIBYTE (1024 * 1024)
#define PACKAGE_VERSION "1.0"


/* Is the program running in the foreground or the background ? */
char foreground;




/*
 * Display the program version and the copyright notice.
 * Called when the --version (-V) option is passed to the program.
 */
void
version ()
{
  printf ("%s (bigmem) %s\n", program_invocation_name, PACKAGE_VERSION);
  (void)puts("Copyright (C) 2011, 2019 Red Hat, Inc.");
}


/*
 * Display the program usage.
 * Called when the --help (-h) option is passed to the program or on input
 * error.
 */
void
help ()
{
  int i;
  char * msg[] = {
    "bigmem is a tool to allocate large amounts of memory in various ways.",
    "",
    "Without any option, bigmem allocates the requested memory using malloc() in",
    "1 MiB chunks and uses memset() to fill those memory chunks.",
    "The following options instruct bigmem to allocate the memory with various",
    "methods:",
    "",
    "  -H, --hugepages   allocate SYS-V style shared-memory segments backed by huge",
    "                    pages.  Each segment is 2 MiB.  The number of segments is",
    "                    computed from the size given as argument.",
    "  -s, --shared      allocate SYS-V style shared-memory segments.  Each segment",
    "                    is 2 MiB and the number of segments is computed from the",
    "                    size given as argument.",
    "  -m, --mmap DIR    allocate POSIX style shared memory backed by huge pages.",
    "                    The DIR directory gives the mount point of the hugetlbfs",
    "                    file system (to mount with mount -t hugetlbfs nodev DIR).",
    "  -T, --transparent allocate memory using malloc() in 8 MiB chunks (and",
    "                    filling it), thus triggering transparent hugepages.",
    "  -v, --virtual     allocate memory using malloc() in 1 MiB chunks, but leave",
    "                    the memory untouched.",
    "  -b, --block       allocate the requested memory in one malloc() call.",
    "",
    "  -h, --help        display this help and exit",
    "  -V, --version     print version information and exit",
"",
NULL
  };


  fprintf ( stderr,
            "Usage: %s [OPTION]... <size>[kKmMgG]\n",
            program_invocation_name);

  for (i = 0; msg[i] != NULL; i++) {
    if (msg[i][0] != '\0') {
      fputs (msg[i], stderr);
    }
    fputc ('\n', stderr);
  }

  fputc ('\n', stderr);
  fprintf (stderr,
     "Exit status is %d on error (%d means no error).\n\n",
     EXIT_FAILURE, EXIT_SUCCESS);
  fputs ("Report bugs to https://training-feedback.redhat.com\n", stderr);
}


/*
 * Signal handler
 */
static void
sig_action (int sig)
{
  return;
}


/*
 * Convert a string to a size_t value (in bytes).
 * The given string can include the k, K, m, M, g, or G suffixes.
 *
 * @param[in] s String to convert.
 * @return The converted value in bytes.
 *         -1 if the given string cannot be converted.
 *         -2 if the suffix is invalid.
 */
size_t
str2size (const char *s)
{
  long long int val;
  char *endptr;


  val = strtoll (s, &endptr, 0);
  if (val <= 0) {
    return -1;
  }

  /* Skip spaces between the value and its suffix */
  while (*endptr != '\0' && isspace (*endptr) != 0) {
    endptr++;
  }
  if (*endptr == '\0') {
    return val;
  }
  if (*endptr == 'k' || *endptr == 'K') {
    return val * 1024LL;
  }
  if (*endptr == 'm' || *endptr == 'M') {
    return val * 1024LL * 1024LL;
  }
  if (*endptr == 'g' || *endptr == 'G') {
    return val * 1024LL * 1024LL * 1024LL;
  }
  return -2;
}


/*
 * Display the PID of the current process.
 */
void
print_mypid ()
{
  printf ("Process PID: %d\n", getpid ());
}


/*
 * Wait for a key press is running in the foreground, or wait indefinitely.
 */
void
press_enter_to_exit ()
{
  sigset_t mask;


  if (foreground != 0) {
    puts ("Press <Enter> to exit");
    fgetc (stdin);
  }
  else {
    /* Infinite wait (until a signal is received) */
    sigprocmask (SIG_BLOCK, NULL, &mask);
    sigsuspend (&mask);
  }
}


/*
 * Allocate the memory with malloc().
 * The allocation is done in chuncks of 1 MiB.
 *
 * @param[in] alloc_size The total memory size to allocate.
 * @param[in] only_virt  If 0, memset() is called on each chunk to fill the
 *                       allocated memory.  Otherwise, the memory is allocated
 *                       but not filled.
 * @return 0 on success, -1 on error (a message is displayed)
 */
int
allocate_4k_pages (size_t alloc_size, char only_virt)
{
  void *s;
  int count, i;


  count = alloc_size / MEBIBYTE;
  printf ("Allocating %d MiB of %s memory (in 1 MiB chunks)...\n",
          count,
          (only_virt == 0) ? "resident" : "virtual");
  i = 0;
  while (i < count) {
    s = malloc (MEBIBYTE);
    if (s == NULL) {
      perror ("malloc");
      return -1;
    }

    if (only_virt == 0) {
      memset (s, 'W', MEBIBYTE);
    }

    if (++i % 10240 == 0 ) {
      printf("Allocated %d MiB\n", i);
    }
  }

  puts ("Done\n");
  press_enter_to_exit ();
  return 0;
}


/*
 * Allocate the memory with malloc() in transparent huge pages.
 * The allocation is done in chuncks of 8 MiB, and if filled with memset().
 *
 * @param[in] alloc_size The total memory size to allocate.
 * @return 0 on success, -1 on error (a message is displayed)
 */
int
allocate_transparent (size_t alloc_size)
{
  void *s;
  int count, i;


  printf ("Allocating %lu MiB of memory (in 8 MiB chunks)\n",
          alloc_size / MEBIBYTE);
  puts ("This should result in anonymous huge pages...");
  count = alloc_size / (MEBIBYTE * 8);
  i = 0;
  while (i < count) {
    s = malloc (MEBIBYTE * 8);
    if (s == NULL) {
      perror ("malloc");
      return -1;
    }

    memset (s, 'W', MEBIBYTE * 8);

    if (++i % 10 == 0 ) {
      printf("Allocated %d MiB\n", i * 8);
    }
  }

  puts ("Done\n");
  press_enter_to_exit ();
  return 0;
}


/*
 * Allocate the memory in SYS-V shared memory segments and fill those segments
 * with memset().
 * The allocation is done in 2 MiB segments.
 *
 * @param[in] alloc_size     The total memory size to allocate.
 * @param[in] use_huge_pages If not 0, the allocation is done with huge pages.
 * @return 0 on success, -1 on error (a message is displayed)
 */
int
allocate_shm (size_t alloc_size, char use_huge_pages)
{
  int count, i;
  int *shm_id;      /* Array to store the segment IDs */
  char **shm_addr;  /* Array to store the segment addresses */


  count = alloc_size / (MEBIBYTE * 2);
  if (use_huge_pages != 0) {
    printf ("Allocating %lu MiB of huge pages (%d pages)\n",
            alloc_size / MEBIBYTE,
            count);
    puts ("Assuming 2 MiB huge pages...");
  }
  else {
    printf ("Allocating %lu MiB of shared memory in 2 MiB segments...\n",
            alloc_size / MEBIBYTE);
  }

  shm_id = (int *) malloc (count * sizeof (int));
  if (shm_id == NULL) {
    perror ("malloc");
    return -1;
  }

  shm_addr = (char **) malloc (count * sizeof (char *));
  if (shm_addr == NULL) {
    perror ("malloc");
    free (shm_id);
    return -1;
  }

  /* Allocating one segment at a time */
  for (i = 0; i < count; i++) {

    shm_id[i] = shmget (IPC_PRIVATE,
                      MEBIBYTE * 2,
                      ((use_huge_pages != 0)? SHM_HUGETLB : IPC_CREAT) | 0600);
    if (shm_id[i] == -1 ) {
      perror ("shmget");
      for (i--; i >= 0; i--) {
        shmdt (shm_addr[i]);
        shmctl (shm_id[i], IPC_RMID, 0);
      }
      free (shm_addr);
      free (shm_id);
      return -1;
    }

    shm_addr[i] = shmat (shm_id[i], NULL, 0);
    if (shm_addr[i] == (char *) -1) {
      perror ("shmat");
      shmctl (shm_id[i], IPC_RMID, 0);
      for (i--; i >= 0; i--) {
        shmdt (shm_addr[i]);
        shmctl (shm_id[i], IPC_RMID, 0);
      }
      free (shm_addr);
      free (shm_id);
      return -1;
    }

    memset (shm_addr[i], 'W', MEBIBYTE * 2);
  }

  puts ("Done\n");
  press_enter_to_exit ();

  /* Cleanup the segments */
  for (i = 0; i < count; i++) {
    shmdt (shm_addr[i]);
    shmctl (shm_id[i], IPC_RMID, 0);
  }
  free (shm_addr);
  free (shm_id);

  return 0;
}


/*
 * Allocate the memory in POSIX shared memory and fill it with memset().
 * Administrator must mount hugetlbfs and the mount point must be provided in
 * the hugetlbfs_dirname parameter.
 *
 * @param[in] alloc_size        The total memory size to allocate.
 * @param[in] hugetlbfs_dirname hugetlbfs file system mount point.
 * @return 0 on success, -1 on error (a message is displayed)
 */
int
allocate_hugepages_mmap (size_t alloc_size, const char *hugetlbfs_dirname)
{
  int fd;
  char *path;
  void *s;


  /* Building the full path to the file to mmap */
#define HUGE_FILENAME "hugepagetest"

  path = (char *) malloc (  strlen (hugetlbfs_dirname)
                          + strlen (HUGE_FILENAME)
                          + 2);
  if (path == NULL) {
    perror ("malloc");
    return -1;
  }
  strcpy (path, hugetlbfs_dirname);
  strcat (path, "/");
  strcat (path, HUGE_FILENAME);

  printf ("Allocating %lu MiB of huge pages by mapping the %s file...\n",
          alloc_size / MEBIBYTE,
          path);

  fd = open (path , O_CREAT | O_RDWR, 0755);
  if (fd < 0) {
    fprintf (stderr,
             "Cannot create the %s file: %s\n",
             path,
             strerror (errno));
    free (path);
    return -1;
  }

  s = mmap (NULL, alloc_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (s == MAP_FAILED) {
		perror ("mmap");
    close (fd);
		unlink (path);
    free (path);
		return -1;
	}

  memset (s, 'W', alloc_size);

  puts ("Done\n");
  press_enter_to_exit ();

  /* Cleanup */
	munmap (s, alloc_size);
	close (fd);
	unlink (path);
  free (path);
  return 0;
}


/*
 * Allocate the memory with malloc() in one call.
 *
 * @param[in] alloc_size The total memory size to allocate.
 * @param[in] only_virt  If 0, memset() is called on the allocated memory.
 *                       Otherwise, the memory is allocated but not filled.
 * @return 0 on success, -1 on error (a message is displayed)
 */
int
allocate_one_big_chunck (size_t alloc_size, char only_virt)
{
  void *s;


  printf ("Allocating %lu MiB of %s memory...\n",
          alloc_size / MEBIBYTE,
          (only_virt == 0) ? "resident" : "virtual");
  s = malloc (alloc_size);
  if (s == NULL) {
    perror ("malloc");
    return -1;
  }

  if (only_virt == 0) {
    memset (s, 'W', alloc_size);
  }

  puts ("Done\n");
  press_enter_to_exit ();
  free (s);
  return 0;
}


int main (int argc, char *argv[])
{
  char flag_h, flag_v, flag_t, flag_s, flag_b, flag_m;
  char *str_size;
  const char *mmap_dir;
  size_t alloc_size;
  struct sigaction sa;
  int option_index, ret;
  struct option long_options[] = {
      { "help", no_argument, 0, 'h' },
      { "version", no_argument, 0, 'V'},
      { "hugepages", no_argument, 0, 'H' },
      { "transparent", no_argument, 0, 'T' },
      { "virtual", no_argument, 0, 'v' },
      { "shared", no_argument, 0, 's' },
      { "block", no_argument, 0, 'b' },
      { "mmap", required_argument, 0, 'm' },
      { 0, 0, 0, 0 }
  };


  flag_h = flag_v = flag_t = flag_s = flag_b = flag_m = 0;
  while (1) {
    option_index = 0;
    ret = getopt_long (argc, argv, "hVHTvsbm:", long_options, &option_index);
    if (ret == -1) {
      break;
    }

    switch (ret) {
      case 'h':
        help ();
        return EXIT_SUCCESS;
      case 'V':
        version ();
        return EXIT_SUCCESS;
      case 'H':
        flag_h = 1;
        break;
      case 'T':
        flag_t = 1;
        break;
      case 'v':
        flag_v = 1;
        break;
      case 's':
        flag_s = 1;
        break;
      case 'b':
        flag_b = 1;
        break;
      case 'm':
        flag_m = 1;
        mmap_dir = optarg;
        break;
      default:
        help ();
        return EXIT_FAILURE;
    }
  }

  if (optind >= argc) {
    fputs ("The allocation size must be provided.\n", stderr);
    help ();
    return EXIT_FAILURE;
  }

  str_size = argv[optind];
  alloc_size = str2size (str_size);
  if (alloc_size <= 0) {
    fprintf (stderr, "Wrong allocation size provided: %s.\n", str_size);
    help ();
    return EXIT_FAILURE;
  }

  /* Signal handling to make sure to cleanup the SYS-V IPCs on exit */
  memset (&sa, 0, sizeof (struct sigaction));
  sa.sa_handler = sig_action;
  sigemptyset (&(sa.sa_mask));
  sa.sa_flags = 0;
  sigaction (SIGINT, &sa, NULL);   /* CTRL+C */
  sigaction (SIGTERM, &sa, NULL);
  sigaction (SIGSEGV, &sa, NULL);
  sigaction (SIGBUS, &sa, NULL);

  /* Check if the program is running in the foregroound */
  foreground = (getpgrp () == tcgetpgrp (STDOUT_FILENO)) ? 1 : 0;
  if (foreground == 0) {
      fclose (stdin);
      fclose (stdout);
  }

  print_mypid ();

  /* --virtual (-v) */
  if (flag_v != 0) {
    allocate_4k_pages (alloc_size, 1);
    return EXIT_SUCCESS;
  }

  /* --transparent (-T) */
  if (flag_t != 0) {
    allocate_transparent (alloc_size);
    return EXIT_SUCCESS;
  }

  /* --hugepages (-H) */
  if (flag_h != 0) {
    allocate_shm (alloc_size, 1);
    return EXIT_SUCCESS;
  }

  /* --share (-s) */
  if (flag_s != 0) {
    allocate_shm (alloc_size, 0);
    return EXIT_SUCCESS;
  }

  /* --block (-b) */
  if (flag_b != 0) {
    allocate_one_big_chunck (alloc_size, 1);
    return EXIT_SUCCESS;
  }

  /* --map DIR (-m DIR) */
  if (flag_m != 0) {
    allocate_hugepages_mmap (alloc_size, mmap_dir);
    return EXIT_SUCCESS;
  }

  allocate_4k_pages (alloc_size, 0);
  return EXIT_SUCCESS;
}
