
# Install dependencies

    sudo apt install --no-install-recommends time=1.7-25.1bem1 fio mplayer sysstat

# For each scheduler, run some tests

## `comm_startup_lat.sh` (latency to start an app)

    # determine base latency
    sudo ./comm_startup_lat.sh  '' 0 0 seq  5 'xterm /bin/true' . 120 '' '' verbose
    # run again with more background IO
    sudo ./comm_startup_lat.sh  '' 1 1 seq  5 'xterm /bin/true' . 120 0.07 '' verbose
    sudo ./comm_startup_lat.sh  '' 2 2 seq  5 'xterm /bin/true' . 120 0.07 '' verbose

To benchmark LibreOffice startup, use something like this:

    sudo ./comm_startup_lat.sh  '' 2 0 seq  5 'flatpak run --no-a11y-bus org.libreoffice.LibreOffice --terminate_after_init' . 240 '' '' verbose

`--no-a11y-bus` is needed to work around some Flatpak bug when running apps under `sudo` that I haven't tracked down yet. Notice the third param (number of writer) is 0, and the 4th-from-last param (timeout) is 240: LibreOffice takes *ages* to start under heavy read load, and with CFQ, under heavy write load, LibreOffice still hadn't started after 8 minutes and I gave up.

I also used this tool to compare base latency with latency while performing some external workload:

    # determine base latency
    sudo ./comm_startup_lat.sh  '' 0 0 seq  5 'xterm /bin/true' . 120 '' '' verbose
    # rename the results file

    # in another terminal, launch some workload
    sudo sh -c 'while true; do flatpak install /path/to/org.gnome.Lollypop.flatpak; flatpak uninstall org.gnome.Lollypop/x86_64/stable; done'

    # in the first terminal
    sudo ./comm_startup_lat.sh  '' 0 0 seq  5 'xterm /bin/true' . 120 '' '' verbose

But at this point it would probably be worth just doing our own benchmark harness.

## `video_play_vs_comms.sh`

The key to getting interesting data here is the penultimate `0` parameter which causes the 5 readers and writer to have no transfer rate limit. (The default rate limit is much too low for SSDs.)

    sudo ./video_play_vs_comms.sh cfq 5 5 rand 5 n real . 0 verbose