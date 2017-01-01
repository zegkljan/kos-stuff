# ----------------------------------------------------------------
# Gravity Turn Maneuver computation server for kOS-equipped
# Kerbal Space Program
#
# Based on:
# Gravity Turn Maneuver with direct multiple shooting using CVodes
# (c) Mirko Hahn
# https://mintoc.de/index.php/Gravity_Turn_Maneuver_(Casadi)
# ----------------------------------------------------------------
import sys
import os
import os.path as pth
import time
import logging
import multiprocessing as mp
import argparse
import textwrap

import koson as ks
import _gturn as gt


class Logger(object):
    def __init__(self, level, name):
        self.level = level
        self.logger = logging.getLogger(name)

    def write(self, message):
        for m in message.splitlines():
            self.logger.log(self.level, m)


def gturn_wrapper(name, **kwargs):
    sout = sys.stdout
    serr = sys.stderr
    sys.stdout = Logger(logging.DEBUG, 'gturn-' + name)
    sys.stderr = Logger(logging.INFO, 'gturn-' + name)
    res = gt.compute_gravity_turn(**kwargs)
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
        if pth.isfile(odata):
            logging.debug('Skipping because result file %s already.', outfile)
            continue
        with open(pth.join(tskdir, idata), mode='r') as f:
            data = ks.load(f)
            logging.debug('Loaded data: %s', str(data))
            tasks.append((d, data))
    return tasks


def write_result(directory, name, result):
    olock = 'output.lock'
    odata = 'output.json'
    tskdir = pth.join(directory, name)
    ofile = pth.join(tskdir, odata)
    lockfile = pth.join(tskdir, olock)
    logging.debug('Writing result of task %s', name)
    logging.debug('Writing lock file %s', lockfile)
    with open(lockfile, mode='w') as f:
        f.write('')
    logging.debug('Writing results file %s', ofile)
    with open(ofile, mode='w') as f:
        ks.dump(result, f)
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


def run(async, directory):
    logging.info('Starting gravity turn computation server. async=%s', async)
    logging.info('Watching directory: %s', directory)
    pool = SwitchPool(async, processes=1)
    running_tasks = dict()
    while True:
        logging.debug('Watching cycle start.')
        tasks = scan_tasks(directory, running_tasks)
        for name, data in tasks:
            running_tasks[name] = pool.apply(gturn_wrapper, args=(name,),
                                             kwds=data)
        for name, res in running_tasks.items():
            if res.ready():
                write_result(directory, name, res.get())
                del running_tasks[name]
        time.sleep(1)
        logging.debug('Watching cycle end.')
        break


def process(infile, outfile):
    print 'Processing file {}.'.format(infile)
    data = None
    with open(infile, mode='r') as f:
        data = js.load(f)
    if data is None:
        print 'Data could not be loaded. Exitting.'
        return

    print 'Computing gravity turn...'
    res = gt.compute_gravity_turn(**data)
    print 'Computation finished.'

    print 'Writing results to {}'.format(outfile)
    with open(outfile, mode='w') as f:
        js.dump(res, f)
    print 'Results written.'


def main(async):
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
    ap.add_argument('-t', '--target',
                    nargs=1,
                    required=True,
                    help='If in server mode, the path specifies the monitored '
                         'directory. If in direct mode, the path specifies the '
                         'input data file.')
    ap.add_argument('-o', '--output',
                    nargs=1,
                    help='If in direct mode, the result will be written to the '
                         'given file. Ignored for server mode.')
    args = ap.parse_args()
    if args.mode[0] in ['server-sync', 'server-async']:
        run(args.mode[0] == 'server-async', args.target[0])
    elif args.mode[0] == 'direct':
        if args.output is None:
            print 'No output file specified for direct mode. Exitting.'
            return
        process(args.target[0], args.output[0])


if __name__ == '__main__':
    main(False)
