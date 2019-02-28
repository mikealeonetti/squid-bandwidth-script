Introduction
============

This script is designed to add to the Squid ACL functionality the ability to limit bandwidth on a per IP or username basis. It does this by setting bandwidth quotas based on a period of time. This script does not duplicate the functionality of [Squid Delay Pools](http://wiki.squid-cache.org/Features/DelayPools). Delay Pools are already in place in Squid to limit the bandwidth on particular types of downloads. If your goal is not limiting the amount of data a workstation/user can use in a day/week/month/year and it just to simply limit the rate at which users can download, Squid Delay Pools are for you.

Squish
------

It is noteworthy that there is also a bandwidth quota program out there so you have alternatives. An alternative to this script is [Squish](http://www.ledge.co.za/software/squint/squish/). Squish offers a variety of features as well. One of them, which is the ability to make pretty graphs, is not yet included in the script that you see here.

This script differs from Squish in the way it was written and stores information. It incorporates some of the Squish engine and ideas and is similar in a lot of ways as well. However, for me the Squish project was not well documented and was a bit hard to figure out how it works. I generally do not like using stuff that I have to read the code to figure out how to install it and how to use it.

**Please note** that if you feel that my scripts are poorly documented and hard to figure out please contact me and I would love to help you out. If you let me know where my documentation needs improving that helps everybody!

How it works
------------

This scripts work by scanning and collecting data from the Squid access.log files and aggregating the byte count per day/week/month/year on a per IP/user basis in a MySQL table (*bandwidth\_calculate*). Then that data is examined and compared against user written rules to see if anybody exceeded their quotas. Those people are then written to another MySQL table. Through through an external ACL, Squid calls another script to cross reference an IP/username with that MySQL table (*bandwidth\_check*).

Prerequisites
-------------

This article also assumes that you have MySQL setup and Squid is already installed with it mostly configured and working.

Installation
============

Downloading and installing
--------------------------
Download the scripts and then extract them. Copy both the *bandwidth\_check* and *bandwidth\_calculate* scripts to the /usr/local/bin directory and then make sure they are executable by at least the user that Squid runs as (running *chmod 755* works for that).

Configuring
-----------

### Creating the MySQL tables

You can use an existing database if you would like. This script uses the same database as the blacklist script, so if you already created it you can just add the tables from the *squidaccess.sql* file (running *mysql squidaccess &lt; squidaccess.sql* as root will do this).

However, if you want to create a new database and import the data use the following steps.

Make sure *squidaccess.sql* is in the current directory.

    # mysql
    mysql> CREATE DATABASE squidaccess;
    mysql> GRANT ALL PRIVILEGES ON squidaccess.* TO squidaccess@localhost IDENTIFIED BY 'squidaccess';
    mysql> use squidaccess;
    mysql> \. squidaccess.sql
    mysq> quit

**Note also** that *bandwidth\_calculate* also creates and drops tables, so the user will need table creation permission. *bandwidth\_calculate* rotates the bandwidth\_blocks table to allow for quicker and smoother updating.

### bandwidth\_calculate

Open up *bandwidth\_calculate* with your favorite text editor and take a look at the following lines.

Set the log directory as well as the access log names. Keep in mind the script **will** examine all of your rotate log files on first run. The log file name is just the basename for all log files in the directory. This usually is **access.log**.

    ########
    # Squid log path and filename
    ########
    my $log_path = "/var/log/squid";
    my $log_file = "access.log";

Set the MySQL database, username, password, and host.

    ########
    # MySQL options
    ########
    my $mysql_host = 'localhost';
    my $mysql_user = 'squidaccess';
    my $mysql_pass = 'squidaccess';
    my $mysql_db = 'squidaccess';

Set extra exclusions. This searches for fields in the **access.log** and skips those lines if they match any of these. This was taken from Squish if it looks familiar to anybody.

For reference, the fields in the Squid access.log file as as follows (also taken from Squish):

| Field number | Field                  |
|--------------|------------------------|
| 0            | date                   |
| 1            | transfer-msec?         |
| 2            | ipaddr                 |
| 3            | status/code            |
| 4            | size                   |
| 5            | operation              |
| 6            | url                    |
| 7            | user                   |
| 8            | method/connected-to... |
| 9            | content-type           |

    ########
    # Options to be excluded from the Squid access log
    ########
    my @excludelist = (
        { "field" => 3, "pattern" => "TCP_DENIED/" } ,
        { "field" => 3, "pattern" => "NONE/" },
        { "field" => 6, "pattern" => '^http://127\.0\.0\.1/' } # localhost
    );

### bandwidth\_check

This script will be run by Squid and not run directly. It can be run directly for testing. Open it up with your favorite editor as well.

Edit the database lines also.

    ## MySQL info
    my $mysql_host = 'localhost';
    my $mysql_user = 'squidaccess';
    my $mysql_pass = 'squidaccess';
    my $mysql_db = 'squidaccess';

### Configuring Squid

Add this to your squid.conf before your ACLs.

    # This will pass the IP. If you would like to use the logged in user via proxy auth, insert %LOGIN after source.
    # for example: external_acl_type bandwidth_check ttl=60 %SRC %LOGIN /usr/local/bin/bandwidth_check
    # Otherwise just use the following line if you are using transparent/interception mode or will not use any means
    # of login.
    external_acl_type bandwidth_check ttl=60 %SRC /usr/local/bin/bandwidth_check

    acl bandwidth_auth external bandwidth_check

*Note that* the recommended ttl is 60 seconds (or 1 minute). You can also use 300 seconds (or 5 minutes) or whatever you will later on set the interval for **bandwidth\_calculate** to run as.

Also, if you wanted to use this script together with the [auth script](Squid_Arms_and_Tentacles:_Authentication "wikilink") you can use **%EXT\_USER** instead.

    external_acl_type bandwidth_check ttl=60 %SRC %EXT_USER /usr/local/bin/bandwidth_check

Now add the ACL **bandwidth\_auth** to your ACLs.

    http_access allow localnet bandwidth_auth

**Also note that** the above rule requires **localnet** to be defined AND it will mean that if **bandwidth\_auth** (or rather the script) returns ERR meaning that the bandwidth is exceeded, the next rule will still be executed. If you wish to deny immediately if the bandwidth is exceeded for a user, use a deny rule instead like so.

    http_access deny localnet !bandwidth_auth

### The rules file

You can put a rules file where ever you would like it to be. A recommended spot may be in your Squid directory. **/etc/squid/bandwidth\_rules** will be used for the remainder of this article.

The rules file is ordered like this.

    ip/username     critera1 [critera2] [critera3] ...
    ip/username     critera1 [critera2] [critera3] ...

That is, each line will handle a separate IP/user. Columns in the file are separated by whitespaces. The first column will always be the username OR IP. Compounding them on a single line will not work. The next columns will be the bytes over the period of time to set the quotas.

IPs can be in the following form

| Type                    | Example                |
|-------------------------|------------------------|
| A subnet mask           | 10.0.0.0/255.255.255.0 |
| A subnet mask with bits | 192.168.1.0/24         |
| A range                 | 10.1.1.100-200         |
| Asterisk matching       | 192.168.168.\*         |
| A single IP             | 192.168.0.231          |

For a username, just specify the username. Case sensitive matching is not performed.

The time periods are accepted in the form \[X\]b/p where **X** is the number of bytes, **b** is the unit multiplier and p is the period of time. Acceptable abbreviations are as follows.

| Abbreviations | Meaning     | Example                                                      |
|---------------|-------------|--------------------------------------------------------------|
| b             | Plain bytes | 268435456000b/w (250 megabytes or 268435456000 bytes a week) |
| kb            | Kilobytes   | 4096kb/d (4096 kilobytes per day)                            |
| mb            | Megabytes   | 500mb/w (500 megabytes per week)                             |
| gb            | Gigabytes   | 10gb/m (10 gigabytes per month)                              |

| Abbreviations | Meaning   | Example                                        |
|---------------|-----------|------------------------------------------------|
| d or day      | Per day   | 40mb/d (50 megabytes a day)                    |
| w or week     | Per week  | 3gb/w (3 gigabytes a week)                     |
| m or month    | Per month | 100gb/m (100 gigabytes a month)                |
| y or year     | Per year  | 1024gb/y (1024 gigabytes or 1 terabyte a year) |

**Space and pound/hash sign escaping** (using \\) can be done for usernames that contain spaces or pound/hash signs. Keep in mind that backslashes (\\) will need to be escaped as well using \\\\.

Now for an example of the rules file.

    # A subnet
    192.168.1.0/24        100mb/d 500mb/w    10gb/m
    # A range
    10.0.0.100-200        200mb/m
    # A single IP
    192.168.2.105        1gb/w 20gb/m
    # A username
    mike                 5gb/w
    # A username with a space
    michael\ leonetti    5gb/w
    # A username and domain separated by a #
    DOMAIN\#mike         5gb/w

### First run setup

Run **bandwidth\_calculate** by hand to make sure there are no errors with your rules file and to do the initial database populate. Depending on how many rotated **access.log** files you have and how much stuff they have in them it can take a while. Specify the rules file path as an option. The script requires this.

    # /usr/local/bin/bandwidth_calculate /etc/squid/bandwidth_rules

If there are no errors try testing the **bandwidth\_check** script to make sure there are no errors. Test it with a couple of IPs.

    # /usr/local/bin/bandwidth_check
    10.0.0.1
    OK
    192.168.1.1
    OK
    ^C

If you get no errors then we are good to go. If you do get some errors and you're not sure what they are, feel free to contact me and we can work them out. This script still is in its beta.

### Setting up your cronjobs

**bandwidth\_calculate** needs to be run at least every 5 minutes to continue calculating the bandwidth usage. So insert it into your crontab file or use

    # crontab -e

And insert the following line

    */5  *  * * *     /usr/local/bin/bandwidth_calculate /etc/squid/bandwidth_rules

This should preferably be run as root, but it can be run as any user as long as that user can read the Squid access log files.

### That's it!

The script should be all ready for use. Reconfigure (**squid -k reconfigure**) or restart Squid and see if it all works. If you experience performance issues you can try adjusting your ttl in the external\_acl\_type or try tuning MySQL.

See Also
========

-   <http://wiki.squid-cache.org/Features/DelayPools>
-   <http://www.ledge.co.za/software/squint/squish/>
