//
//  TelnetServer.m
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#import <Foundation/Foundation.h>


#pragma mark - commands
int ls_main(int argc, char **argv) {
    return 0;
}

int cd_main(int argc, char **argv) {
    return 0;
}

int pwd_main(int argc, char **argv) {
    return 0;
}

int mkdir_main(int argc, char **argv) {
    return 0;
}

int touch_main(int argc, char **argv) {
    return 0;
}

int rm_main(int argc, char **argv) {
    return 0;
}

int mv_main(int argc, char **argv) {
    return 0;
}

int cp_main(int argc, char **argv) {
    return 0;
}

int cat_main(int argc, char **argv) {
    return 0;
}

int printenv_main(int argc, char **argv) {
    return 0;
}

int set_main(int argc, char **argv) {
    return 0;
}

int export_main(int argc, char **argv) {
    return 0;
}

int echo_main(int argc, char **argv) {
    return 0;
}

int id_main(int argc, char **argv) {
    return 0;
}


int who_main(int argc, char **argv) {
    return 0;
}


int whoami_main(int argc, char **argv) {
    return 0;
}

int uname_main(int argc, char **argv) {
    return 0;
}

int swvers_main(int argc, char **argv) {
    return 0;
}


int open_main(int argc, char **argv) {
    return 0;
}


int head_main(int argc, char **argv) {
    return 0;
}


int tail_main(int argc, char **argv) {
    return 0;
}


int machoparse_main(int argc, char **argv) {
    return 0;
}


int reboot_main(int argc, char **argv) {
    return 0;
}


int respring_main(int argc, char **argv) {
    return 0;
}

int kill_main(int argc, char **argv) {
    return 0;
}

int killall_main(int argc, char **argv) {
    return 0;
}


int wget_main(int argc, char **argv) {
    return 0;
}


int help_main(int argc, char **argv) {
    return 0;
}

#pragma mark - Server

int DEFAULT_TELNET_PORT = 23;
int LOOPBACK_MODE = 0;
int LOCAL_MODE = 1;
int NORMAL_MODE = 2;

int start_telnet_server(int port, int mode) {
    
    if(port <= 0 || port >= 65536) {
        port = DEFAULT_TELNET_PORT;
    }
    
    if(mode < 0 || mode >= 3) {
        mode = LOOPBACK_MODE;
    }
    
    printf("Starting telnet on port %d...\n", port);
    printf("The server will use mode: %#x", mode);
    
    return 0;
}

