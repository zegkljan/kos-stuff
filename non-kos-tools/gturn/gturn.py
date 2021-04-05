# ----------------------------------------------------------------
# Gravity Turn Maneuver computation server for kOS-equipped
# Kerbal Space Program
#
# Based on:
# Gravity Turn Maneuver with direct multiple shooting using CVodes
# (c) Mirko Hahn
# https://mintoc.de/index.php/Gravity_Turn_Maneuver_(Casadi)
# ----------------------------------------------------------------
import argparse
import logging
import multiprocessing as mp
import os
import os.path as pth
import sys
import textwrap
import time
import numpy as np
import subprocess

import _gturn as gt
import koson as ks


class ProcessorLogger(object):
    def __init__(self, level, name, file):
        self.level = level
        self.logger = logging.getLogger(name)
        self.file = file

        if self.file is not None:
            open(self.file, mode='w').close()

    def write(self, message):
        if self.file is not None:
            with open(self.file, mode='a') as f:
                f.write(message)
        for m in message.splitlines():
            self.logger.log(self.level, m)


def gturn_wrapper(name, task_dir, store_logs, **kwargs):
    sout = sys.stdout
    serr = sys.stderr
    if store_logs:
        sys.stdout = ProcessorLogger(logging.DEBUG, 'gturn-' + name,
                                     pth.join(task_dir, 'stdout.txt'))
        sys.stderr = ProcessorLogger(logging.INFO, 'gturn-' + name,
                                     pth.join(task_dir, 'stderr.txt'))
    else:
        sys.stdout = ProcessorLogger(logging.DEBUG, 'gturn-' + name, None)
        sys.stderr = ProcessorLogger(logging.INFO, 'gturn-' + name, None)
    try:
        res = gt.compute_gravity_turn(**kwargs)
    finally:
        sys.stdout = sout
        sys.stderr = serr
    return res


def scan_tasks(directory, skip_tasks):
    logging.debug('Scanning master directory %s', directory)
    ilock = 'input.lock'
    idata = 'input.json'
    odata = 'output.json'
    tasks = []
    for d in os.listdir(directory):
        tskdir = pth.join(directory, d)
        logging.debug('Scanning %s', tskdir)
        if not pth.isdir(tskdir):
            logging.debug('Skipping because %s is not a directory.', tskdir)
            continue
        if d in skip_tasks:
            logging.debug('Skipping because %s is among skip tasks.', d)
            continue
        lockfile = pth.join(tskdir, ilock)
        if pth.isfile(lockfile):
            logging.debug('Skipping because lock file %s exists.', lockfile)
            continue
        datfile = pth.join(tskdir, idata)
        if not pth.isfile(datfile):
            logging.debug('Skipping because %s does not exist or is not '
                          'a file.', datfile)
            continue
        outfile = pth.join(tskdir, odata)
        if pth.isfile(outfile):
            logging.debug('Skipping because result file %s already.', outfile)
            continue
        logging.debug('Found fresh data.')
        with open(pth.join(tskdir, idata), mode='r') as f:
            data = ks.load(f)
            logging.debug('Loaded data: %s', str(data))
            tasks.append((d, tskdir, data))
    return tasks


def write_result(directory, name, result, indent, write_raw_data):
    if indent:
        indent = 2
    olock = 'output.lock'
    odata = 'output.json'
    odata_raw = 'output-raw.txt'
    tskdir = pth.join(directory, name)
    ofile = pth.join(tskdir, odata)
    ofile_raw = pth.join(tskdir, odata_raw)
    lockfile = pth.join(tskdir, olock)

    logging.debug('Writing result of task %s', name)
    logging.debug('Writing lock file %s', lockfile)
    with open(lockfile, mode='w') as f:
        f.write('')

    logging.debug('Writing results file %s', ofile)
    with open(ofile, mode='w') as f:
        ks.dump(result, f, indent=indent)

    if write_raw_data:
        logging.debug('Writing raw results file %s', ofile_raw)
        bigdata = np.column_stack([result[key]
                                   for key in sorted(result.keys())])
        np.savetxt(ofile_raw, bigdata, delimiter='\t',
                   header='\t'.join(sorted(result.keys())))

    logging.debug('Removing lock file %s', lockfile)
    os.unlink(lockfile)
    logging.debug('Done.')


class SwitchPool(object):
    class SyncResult(object):
        def __init__(self, r):
            self.r = r

        def ready(self):
            return True

        def get(self):
            return self.r

    def __init__(self, async, processes):
        if async:
            self.pool = mp.Pool(processes=processes)
        self.async = async

    def apply(self, func, args=(), kwds=()):
        if self.async:
            return self.pool.apply_async(func, args=args, kwds=kwds)
        else:
            return SwitchPool.SyncResult(func(*args, **kwds))


def run(async, directory, indent, store_logs, write_raw_data):
    logging.info('Starting gravity turn computation server. async=%s', async)
    logging.info('Watching directory: %s', directory)
    pool = SwitchPool(async, processes=1)
    running_tasks = dict()
    while True:
        logging.debug('Watching cycle start.')
        tasks = scan_tasks(directory, running_tasks)
        for name, task_dir, data in tasks:
            running_tasks[name] = pool.apply(gturn_wrapper,
                                             args=(name, task_dir, store_logs),
                                             kwds=data)
        for name in list(running_tasks.keys()):
            res = running_tasks[name]
            if res.ready():
                write_result(directory, name, res.get(), indent, write_raw_data)
                del running_tasks[name]
        time.sleep(10)
        logging.debug('Watching cycle end.')


def process(infile, outfile, indent, store_logs, write_raw_data,
            postprocess_command):
    if indent:
        indent = 2
    logging.info('Processing file {}.'.format(infile))
    with open(infile, mode='r') as f:
        data = ks.load(f)
    if data is None:
        logging.error('Data could not be loaded. Exitting.')
        return

    logging.debug('Computing gravity turn...')
    res = gturn_wrapper('processor', pth.dirname(outfile), store_logs, **data)
    logging.debug('Computation finished.')
    if res is None:
        logging.error('Failed to compute. No results written.')
        return

    if outfile is None:
        logging.debug('Writing results to stdout')
        ks.dump(res, sys.stdout, indent=indent, sort_keys=True)

        if write_raw_data:
            logging.debug('Writing raw results to stdout')
            bigdata = np.column_stack([res[key]
                                       for key in sorted(res.keys())])
            np.savetxt(sys.stdout.buffer, bigdata, delimiter='\t',
                       header='\t'.join(sorted(res.keys())))
    else:
        logging.debug('Writing results to %s', outfile)
        with open(outfile, mode='w') as f:
            ks.dump(res, f, indent=indent, sort_keys=True)

        if write_raw_data:
            ofile_raw = pth.join(pth.dirname(outfile), 'output-raw.txt')
            logging.debug('Writing raw results file %s', ofile_raw)
            bigdata = np.column_stack([res[key]
                                       for key in sorted(res.keys())])
            np.savetxt(ofile_raw, bigdata, delimiter='\t',
                       header='\t'.join(sorted(res.keys())))

    if postprocess_command is not None:
        subprocess.run(postprocess_command, shell=True,
                       cwd=pth.dirname(outfile))
    logging.info('Results written.')


def main():
    logging.basicConfig(level=logging.DEBUG)
    epilog = '''
    RUN MODES

    The program can run in three modes: server-sync, server-async and direct.

    Modes server-sync, server-async

    Both of these modes have the same logic and their difference is explained at
    the end of this section. Both of these modes can be called server modes.

    In a server mode the program periodically checks the given directory for
    input data files. Whenever it detects a ready data file it loads it and
    dispatches a computation task to compute a gravity turn based on the data
    loaded from the file. The result is written to the corresponding file. In
    this mode the program runs until manually interrupted (e.g. by Ctrl+C).

    The monitored directory is expected to contain subdirectories, one for each
    computation (let's call these "task dirs"). A task dir can contain these
    files:
        * input.json  - input data file in JSON format
        * input.lock  - if this file exists (can be empty) the program won't try
                        to load the input.json file
        * output.json - result of the computation in JSON format; if this file
                        exists (even if it is empty) the program won't try to
                        load the input.json file (to prevent multiple
                        computations of the same thing); this file is written by
                        this program
        * output.lock - if this file exists it is not safe to read the
                        output.json file; this file is written and deleted by
                        this program
    The output data and lock (output.json and output.lock) are written into the
    same task dir where the corresponding input.json was located.

    The difference between server-sync and server-async is that in sync mode the
    computations are performed synchronously, i.e. when a valid input data file
    is detected it is loaded and processed and only after the computation is
    finished and the result is written the monitoring resumes. In async mode the
    input data files are read as they come and the computations are dispatched
    as asynchronous tasks in their own processes, i.e. two computations can run
    concurently (if properly configured).

    Direct mode

    In direct mode the program loads the given input data file, computes the
    gravity turn and writes the result to the given output data file and then
    exits. In contrast to the server mode, in direct mode the file is always
    loaded and the result is always written, no locks are checked.
    '''
    ap = argparse.ArgumentParser(prog='gturn.py',
                                 description='Utility for computing gravity '
                                             'turns.',
                                 epilog=textwrap.dedent(epilog),
                                 formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument('-m', '--mode',
                    nargs=1,
                    choices=['server-sync', 'server-async', 'direct'],
                    default='server',
                    required=False,
                    help='Specifies the mode the program will run in. See '
                         'information about run modes. Default is server-sync '
                         'mode.')

    def check_processes(x):
        try:
            x = int(x)
            if x <= 0:
                raise ValueError()
            return x
        except ValueError:
            raise argparse.ArgumentTypeError('Number of processes must be an '
                                             'integer greater than 0.')
    ap.add_argument('-p', '--processes',
                    nargs=1,
                    required=False,
                    default=1,
                    type=check_processes,
                    help='Specifies the number of simultaneous computation '
                         'processes (not counting the main process scanning '
                         'the directory) that can run concurrently. Must be '
                         'greater than 0. Default is 1.')
    ap.add_argument('-t', '--target',
                    nargs=1,
                    required=True,
                    help='If in server mode, the path specifies the monitored '
                         'directory. If in direct mode, the path specifies the '
                         'input data file.')
    ap.add_argument('-o', '--output',
                    nargs=1,
                    help='If in direct mode, the result will be written to the '
                         'given file. If not present, the result will be '
                         'printed to the standard output. Ignored for server '
                         'mode.')
    ap.add_argument('-i', '--indent',
                    action='store_true',
                    help='If specified, the output files (regardless of the '
                         'mode or the destination file) will be indented.')
    ap.add_argument('--write-computation-log',
                    action='store_true',
                    help='If specified, the raw log of the computation will be '
                         'stored to a file. The log is stored in the '
                         'corresponding task dir in case of server mode, or in '
                         'the directory of the output file if in direct mode '
                         'with --output option specified. If in direct mode '
                         'and --output is not specified, no log will be '
                         'printed.')
    ap.add_argument('--write-raw-data',
                    action='store_true',
                    help='If specified, the raw data in gnuplot-compatible '
                         'format will be written to a file. The file is stored '
                         'in the corresponding task dir in case of server '
                         'mode, or in the directory of the output file if in '
                         'direct mode with --output option specified. If in '
                         'direct mode and --output option is not specified, '
                         'the data will be printed to standard output after '
                         'the kOS-JSON data.')
    ap.add_argument('--postprocess-command',
                    nargs=1,
                    help='If specified, this command will be run after the '
                         'computation has finished. The working directory of '
                         'the command will be the task dir in case of server '
                         'mode, directory containing the output file in case '
                         'of direct mode with --output specified, or the '
                         'working directory of this program (gturn) in case of '
                         'direct mode without --output option specified.')
    args = ap.parse_args()
    if args.mode[0] in ['server-sync', 'server-async']:
        run(async=args.mode[0] == 'server-async',
            directory=args.target[0],
            indent=args.indent,
            store_logs=args.write_computation_log,
            write_raw_data=args.write_raw_data)
    elif args.mode[0] == 'direct':
        if args.output is None:
            output = None
        else:
            output = args.output[0]
        if args.postprocess_command is None:
            postprocess = None
        else:
            postprocess = args.postprocess_command[0]
        process(infile=args.target[0],
                outfile=output,
                indent=args.indent,
                store_logs=args.write_computation_log,
                write_raw_data=args.write_raw_data,
                postprocess_command=postprocess)


if __name__ == '__main__':
    main()
