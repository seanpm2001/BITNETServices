/*--------------------------------------------------------------------*/
/*                                                                    */
/*                       ++  X  Y  Z  Z  Y  ++                        */
/*                          --FOR WAKEUP-------------                 */
/*                            Release 2.5                             */
/*                     A "Deluxe" Chatting Exec FOR WAKEUP            */
/*          Created by David Bolen (Mithrandir) - DB3L@CMUCCVMA       */
/*             Copyright (c) 1986,1987 - All Rights Reserved          */
/*              Requires: WAKEUP MODULE  and one of                   */
/*                        VMFCLEAR MODULE / CLRSCRN MODULE            */
/*                                                                    */
/*  Special thanks to the following people for help with both initial */
/*  debugging and for testing later releases:                         */
/*                Charlene Mudford - University of Regina             */
/*                Jim MacKenzie    - University of Regina             */
/*                Charlotte Dick   - Texas A&M University             */
/*                Douglas Evans    - University of Nebraska           */
/*                David Buechner   - Georgia Tech                     */
/*                                                                    */
/*  Send mail to be included in the list of those receiving updates,  */
/*  or to make comments on the program.                               */
/*                                                                    */
/*  Refer to end of exec for Program History.                         */
/*--------------------------------------------------------------------*/
 
parse arg parameters
signal on halt
signal on syntax
TimerInit = time('R')
call Initialize
 
/*--------------------------------------------------------------------*/
/*                         Main Program Loop                          */
/*--------------------------------------------------------------------*/
do forever
  'wakeup +00:00:60 (iucvmsg cons quiet'
  msgtype = rc
  if (setting.clock = 'Y') | (clock_alarm ¬= '') then
    call clock_tick
  if msgtype = clockend then iterate
  parse pull line
  select
    when (msgtype = console) then
      call Outgoing line
    when (msgtype = normal) then
      call Incoming line
    otherwise
      call Confused line
  end /* select */
  HookReturn = 0; HookUser = '' /* reset any possible hook */
end /* do forever */
 
 
/*--------------------------------------------------------------------*/
/*   Routine to convert any legal "id" into an internal id "packet"   */
/*--------------------------------------------------------------------*/
convert:
  parse arg conv_line '!' local_nick .
  if (local_nick ¬= '') then convert_cache = ''
  conv_count = conv_count + 1
  conv_line = translate(strip(conv_line))
  if (translate(local_nick,'abcdefghijklmnopqrstuvwxyz',,
                           'ABCDEFGHIJKLMNOPQRSTUVWXYZ')) = local_nick
    then upper local_nick
  if (words(conv_line) = 3) & (word(conv_line,2) = 'AT') then
    conv_line = word(conv_line,1)'@'word(conv_line,3)
  if (index(conv_line,'@') ¬= 0) then conv_line = space(conv_line,0)
  if (words(conv_line) ¬= 1) then return 'ERROR'
  if (left(conv_line,1) = '.') then return 'ERROR'
 
  cindex = find(convert_cache,conv_line)
  if (cindex ¬= 0) then return word(convert_cache,cindex+1)
  if ( (words(convert_cache)/2) > setting.convsize ) then
    convert_cache = subword(convert_cache,3)
 
  parse var conv_line conv_user '@' conv_node
  if (conv_user = '') then return 'ERROR'
 
  if (index(conv_user,'%') ¬= 0) then do
    parse var conv_user conv_user '%' rest
    rest = translate(rest,' ','%') conv_node
    conv_node = word(rest,1)
    if (strip(subword(rest,2) = '')) then return 'ERROR'
    route.conv_node = strip(subword(rest,2))
    if (find(routings,conv_node) = 0) then routings = routings conv_node
  end
  if (conv_node ¬= '') then do
    conv_nick  = 'NONE'
    conv_found = 0
    do conv_index = 1 to num_talking
      parse var talking.conv_index tuser '@' tnode '!' tnick
      if (tuser = conv_user) & (tnode = conv_node) then do
        conv_nick  = tnick
        conv_found = 1
        leave conv_index
      end /* if */
    end /* do */
    if (¬conv_found) then do
      makebuf ; bufnum = rc
      'namefind :userid' conv_user ':node' conv_node,
                ':nick (stack file' setting.namefile
      if (rc = 0) then
        parse pull conv_nick
      else if (conv_node = xyzzy_node) then do
        'namefind :userid' conv_user ':nick (stack file' setting.namefile
        if (rc = 0) then
          parse pull conv_nick
      end
      dropbuf bufnum
    end
  end
  else do
    if (datatype(conv_user) = 'NUM') then do
      if (conv_user > 0) & (conv_user <= num_talking) then do
        cindex = strip(conv_user,'L','0')
        if (local_nick = '') then return talking.cindex
          else do
            parse var talking.cindex tuser '@' tnode '!' tnick
            convert_cache = convert_cache conv_line,
                              tuser'@'tnode'!'local_nick
            return tuser'@'tnode'!'local_nick
          end
      end
      else if (conv_user < 0) & (-conv_user <= num_ignoring) then do
        temp = -conv_line
        convert_cache = convert_cache conv_line ignoring.temp
        return ignoring.temp
      end
    end
    makebuf ; bufnum = rc
    conv_found = 0
    do conv_index = 1 to num_talking
      parse var talking.conv_index tuser '@' tnode '!' tnick
      if (tuser = conv_user) | (translate(tnick) = conv_user) then do
        conv_user  = tuser
        conv_node  = tnode
        conv_nick  = tnick
        conv_found = 1
        leave conv_index
      end /* if */
    end /* do */
    if (¬conv_found) then do
      'namefind :nick' conv_user,
               ':nick :userid :node (stack file' setting.namefile
      if (rc = 0) then do
        parse pull conv_nick
        pull conv_user
        pull conv_node; if (conv_node = '') then conv_node = xyzzy_node
      end
      else do
        'namefind :userid' conv_user,
                 ':nick :node (stack file' setting.namefile
        if (rc = 0) then do
          parse pull conv_nick
          pull conv_node; if (conv_node = '') then conv_node = xyzzy_node
        end
        else do
          conv_node = xyzzy_node
          conv_nick = 'NONE'
        end /* local user */
      end /* check for nickname */
    end /* check for user */
    dropbuf bufnum
  end /* check single word */
  dropbuf bufnum
  if (local_nick ¬= '') then conv_nick = local_nick
  if (conv_nick = 'NONE') & (translate(conv_line) = 'AUTHOR') then do
    conv_user = author_user;  conv_node = author_node
    conv_nick = translate('David$Bolen$-$XYZZY$Author','01'x,'$')
  end
  creturn = space(conv_user'@'conv_node'!'conv_nick,0)
  convert_cache = convert_cache conv_line creturn
return creturn
 
 
/*--------------------------------------------------------------------*/
/* Routine to convert 24 hour time string to something nicer..        */
/*--------------------------------------------------------------------*/
convert_time:
  arg hour':'min':'sec
  if left(hour,1) = '0' then hour = right(hour,1)
  if length(min) = 1 then min = '0'min
  if (sec ¬= '') then out1 = ':'sec ; else out1 = ''
  select
    when (hour = 0) & (min = 0) then out = 'Midnight'
    when (hour = 0) & (min ¬= 0) then out = 12':'min || out1 'am'
    when (hour = 12) & (min = 0) then out = 'Noon'
    when (hour > 0) & (hour < 12) then out = hour':'min || out1 'am'
    when (hour > 12) then out = (hour-12)':'min || out1 'pm'
    otherwise out = hour':'min || out1 'pm'
  end /* select */
return out
 
 
/*--------------------------------------------------------------------*/
/* Clock tick routine - occurs each command or at least once a minute */
/*--------------------------------------------------------------------*/
clock_tick:
  clock_time = left(time(),5)
  parse var clock_time hr ':' min
  if (setting.clock = 'Y') then do
    if ((min > 29) & (min < 33) & (clock_shown ¬= 30)) |,
       ((min < 03) & (clock_shown ¬= 00)) then do
      if (setting.beepcmd ¬= '') then
        interpret "'" || setting.beepcmd || "'"
      if (setting.beepchar ¬= '') then call sendl setting.beepchar
      call sendl ''
      call sendl hi || '****** Time is now:',
                 convert_time(clock_time) '******' || lo
      call sendl ''
      if (min < 30) then
        clock_shown = 00
      else
        clock_shown = 30
    end /* if */
  end /* if setting.clock */
  if (clock_alarm ¬= '') & (¬showed_alarm) then do
    parse var clock_alarm ahr ':' amin
    diff = min - amin
    if (abs(ahr) = abs(hr)) & (diff >= 0) &,
       (diff < 3) & (¬showed_alarm) then do
      if (setting.beepcmd ¬= '') then
        interpret "'" || setting.beepcmd || "'"
      if (setting.beepchar ¬= '') then call sendl setting.beepchar
      atime = convert_time(clock_time)
      call sendl ''
      call sendl hi || '********************************'|| lo
      call sendl hi || '***** Time is now:',
                 atime left('******',12-length(atime)) || lo
      call sendl hi || '********************************'|| lo
      call sendl ''
      showed_alarm = 1
    end /* alarm */
  end
return /* clock_tick */
 
 
/*--------------------------------------------------------------------*/
/*                 Handler for incoming messages                      */
/*--------------------------------------------------------------------*/
 
Incoming:
  parse arg . in_line
  if (hook.hooklowlevel.astx ¬= '') then do
    in_packet = '' ; in_msg = in_line
    call call_hook hook.hooklowlevel.astx
    if HookReturn then return
  end /* if */
  if (word(in_line,1) ¬= net_machine) then do
    in_packet = convert(word(in_line,1) '@' xyzzy_node)
    in_msg = subword(in_line,2)
    call incoming_convo in_packet in_msg
  end /* if not RSCS message */
  else do
    parse var in_line . rest
    rest = strip(rest)
    if (translate(word(rest,1)) = 'FROM') then
      rest = 'FROM' subword(rest,2)
    if ( (xyzzy_node = 'CLVM') | (xyzzy_node = 'UCSFVM') ) &,
       ( (index(rest,':') <= 10) | (index(rest,'(') <= 10) ) &,
       ( word(rest,1) ¬= 'CPQ:' ) then
     rest = 'FROM' rest
    loc = index(rest,'):')
    if ( (loc ¬= 0) & (loc < index(rest,':')) ) then do
      parse var rest 'FROM' node '(' user '):' in_msg
      in_packet = convert(user'@'node)
      if (in_packet = 'ERROR') then do
        call warning 'Invalid message received:' rest
        return
      end /* if */
      call incoming_convo in_packet strip(in_msg,'L')
      return
    end /* normal msg */
    if (index(rest,'FROM') ¬= 0) then
      parse var rest 'FROM' node ':' in_msg
    else do
      node = xyzzy_node ; in_msg = rest
    end
    node = strip(node)
    in_packet = 'RSCS@'node'!NONE'   /* for expansion routines */
    if (find(hook_index.hookrscs,node) = 0) then node = astx
    if (hook.hookrscs.node ¬= '') then
      call call_hook hook.hookrscs.node
    if HookReturn then return
 
    select
      when (index(rest,'CPQ:') ¬= 0) then do
        call incoming_query rest
      end /* incoming query */
      when (index(rest,'SPOOLED') ¬= 0)&(index(rest,'ORG') ¬= 0) then do
        call incoming_file rest
      end /* incoming file */
      when (index(translate(rest),'FILE') ¬= 0) |,
           (index(translate(rest),'SENT ON LINK') ¬= 0)
       then do   /* second check was so we also trap MVS messages */
        call file_transmission rest
      end /* file transmission */
      otherwise do
        call incoming_rscs rest
      end /* otherwise */
    end /* select */
  end /* else */
return /* Incoming */
 
 
/* handle incoming messages */
incoming_convo:
  parse arg in_packet in_msg
  if (in_msg = '. .') then do
    old_setting = setting.history
    setting.history = 0
    call send in_packet xyzzy_version
    if (xyzzy_node = author_node) & (xyzzy_user = author_user) then
      call sendl hi || 'Version request received:' || lo ||,
                 expand(in_packet)
    setting.history = old_setting
    return
  end /* if */
  ilocate = locate('ignoring' in_packet)
  tlocate = locate('talking' in_packet)
  parse var in_packet hindex '!' .
  hook_cmd = ''
  if (tlocate ¬= 0) then do
    hook_cmd = hook.hooktalking.hindex
    if (find(hook_index.hooktalking,hindex) = 0) then
      hook_cmd = hook.hooktalking.astx
  end
  if (ilocate ¬= 0) then do
    hook_cmd = hook.hookignoring.hindex
    if (find(hook_index.hookignoring,hindex) = 0) then
      hook_cmd = hook.hookignoring.astx
  end
  if (hook_cmd = '') then do
    hook_cmd = hook.hookmessage.hindex
    if (find(hook_index.hookmessage,hindex) = 0) then
      hook_cmd = hook.hookmessage.astx
  end
  if (hook_cmd ¬= '') then
    call call_hook hook_cmd
  if HookReturn then return
  test = author_user'@'author_node
  if (left(in_msg,1) = '&') & (left(in_packet,length(test)) = test)
    then do
      tlocate = 1  ;  in_msg = substr(in_msg,2)
    end
  if ((setting.ignoreall = 'N') & (ilocate = 0)) | (tlocate ¬= 0) then do
    if ((setting.timemark = 'Y') &,
       ((time('E') - old_time) > setting.timedelay)) then
      call display 'NODISPLAY' '('date() '-' time()')'
    old_time = time('E')
    call display in_packet in_msg
  end /* not ignoring */
  else if (left(word(in_msg,1),1) ¬= '*') then do
    parse var in_packet log_user '@' log_node '!' log_nick
    log_string = date() time()
    if (log_nick ¬= 'NONE') then
      log_string = log_string 'from' log_nick ': '
    else
      log_string = log_string 'from' '('log_node')'log_user ': '
    if (setting.logignore = 'Y') then do
      'EXECIO 1 DISKW XYZZY IGNLOG A0 (FINIS STRING' log_string in_msg
      ignore_logged = 1   /* at least one message has been logged */
    end /* if log message */
    if (log_node ¬= old_log_node) | (log_user ¬= old_log_user) |,
       ((time('E') - old_log_time) > setting.igndelay) then do
      old_log_node = log_node
      old_log_user = log_user
      old_setting = setting.history
      old_setting1 = setting.outsize
      old_setting2 = setting.mprefix
      setting.history = 0
      setting.outsize = 1000000
      setting.mprefix = ''
      call send in_packet '*>>' setting.ignmsg
      setting.mprefix = old_setting2
      setting.outsize = old_setting1
      setting.history = old_setting
      if (setting.ignore = 'Y') then
        call sendl 'Message ignored from:' expand(in_packet)
    end /* if ok to send msg */
    old_log_time = time('E')
  end /* ignoring */
return /* incoming_msg */
 
/* Handler for incoming query returns */
incoming_query:
  parse arg line
  rest = translate(line)
  if (index(rest,'FROM') = 0) then do
    node = xyzzy_node
    parse var rest 'CPQ:' user extra
  end /* if */
  else do
    parse var rest 'FROM' node ':' 'CPQ:' user extra
  end /* else */
  qlocate = index(user,'-')
  if (qlocate ¬= 0) & (length(user) > 8) then do
    extra = substr(user,qlocate) extra
    user = substr(user,1,qlocate-1)
  end /* if */
  if (length(user) > 8) then
    parse var extra user extra
  query_packet = convert(user'@'node)
  if (right(query_packet,4) = 'NONE') | (query_packet = 'ERROR') then do
    parse var line beg 'CPQ:' extra
    old_setting = setting.jmsg  /* make sure this gets displayed */
    setting.jmsg = 'Y'
    call incoming_rscs beg extra
    setting.jmsg = old_setting
    return
  end /* if error */
  display_allowed = 0
  if (index(extra,'DSC') ¬= 0) then dsc = 1 ; else dsc = 0
  if (index(extra,'NOT') ¬= 0) then not = 1 ; else not = 0
  if (setting.querydsc = 'Y') & (dsc) then do
    extra = 'Disconnected'
    display_allowed = 1
  end /* if disconnected */
  else if (setting.querynot = 'Y') & (not) then do
    extra = 'Not logged in'
    display_allowed = 1
  end /* if not logged on */
  else if (setting.querylog = 'Y') & (¬dsc) & (¬not) then do
    if (index(extra,'-') ¬= 0) then
      extra = 'Logged in ('strip(substr(extra,index(extra,'-')+1))')'
    else
      extra = 'Logged in ('strip(substr(extra,index(extra,' ')+1))')'
    display_allowed = 1
  end /* if logged on */
  if (display_allowed) then do
    old_setting = setting.rnick
    setting.rnick = 'Y'
    call display query_packet extra
    setting.rnick = old_setting
  end /* if */
return /* incoming_query */
 
/* Routine to handle incoming file messages */
incoming_file:
  parse arg 'FILE (' file_id ')' . 'ORG ' from_node,
            '(' from_user ')' from_info
  file_packet = convert(from_user'@'from_node)
  parse var file_packet user '@' node '!' nick
  if (nick ¬= 'NONE') then header = nick
    else header = user'@'node
  old_show = setting.shownick
  setting.shownick = 'Y'
  call display 'junk@junk!Received',
             'File' file_id 'from' header', sent' from_info
  setting.shownick = old_show
return /* incoming_file */
 
/* Routine to handle file transmission messages */
file_transmission:
  parse arg rest
  if (setting.filetrack = 'N') then do
    call incoming_rscs rest
    return
  end
  if (index(rest,'FROM') = 0) then do
    node = xyzzy_node
    remain = rest
  end /* if */
  else do
    parse var rest 'FROM' node ':' remain
  end /* else */
  upper remain
  if right(remain,9) = 'NOT FOUND' then do
    parse var remain 'FILE' orgid 'NOT FOUND'
    orgid = strip(orgid)
    if (file_query.orgid ¬= 'FILE_QUERY.'orgid) then do
      drop file_query.orgid
      return
    end
  end
  if (index(remain,'FILE') = 0) then                /* make MVS msgs */
    parse var remain 'RSCS' orgid prefix stat info  /* like RSCS */
  else do
    if (index(remain,'(') = 0) then   /* for vaxes */
      parse var remain prefix 'FILE' orgid stat info
    else
      parse var remain prefix 'FILE' . '(' orgid ')' stat info
  end
  prefix = strip(prefix);
  if (left(prefix,3) = 'DMT') then
    prefix = subword(prefix,2)
  dtime = '  ('date(U) time()')'
  select
    when (stat = 'ENQUEUED') then do  /* File initially placed on link */
      address command cp 'SMSG' net_machine 'QUERY FILE' orgid 'VM'
      file_query.orgid = time()
      parse var info 'LINK' enqlink
      files_index = files_index orgid
      files.orgid = 'Enqueued on link' strip(enqlink)
      files_time.orgid = dtime
    end /* enqueued */
    when (stat = 'PENDING') then do  /* File waiting for open slot */
      parse var info 'LINK' pndlink
      if (files.orgid = '') then
        files_index = files_index orgid
      if (files.orgid ¬= '') then
        parse var files.orgid '(' destuser '@' destnode .
      if (destuser ¬= '') then more = ', destination',
                               strip(destuser)' @ 'strip(destnode)
        else more = ''
      files.orgid = 'Pending on link' strip(pndlink) || more
      files_time.orgid = dtime
    end /* pending */
    when (stat = 'ON') & (left(prefix,4) = 'SENT') then do
      parse var info 'LINK' link ' TO ' destination
      if (index(destination,'(') ¬= 0) then
        parse var destination destnode'('destuser')' .
      else
        parse var destination destnode destuser
      if (destuser = '') then       /* fix for MVS messages */
        parse var files.orgid 'destination' destuser '@' .
      link = strip(link)
      destnode = strip(destnode); destuser = strip(destuser)
      if (files.orgid = '') then
        files_index = files_index orgid
      if (link = destnode) then do
        files.orgid = '* Reached destination ('destuser' @ 'destnode')'
        files_time.orgid = dtime
        if (setting.fnotify = 'Y') then do
          if (files_header.orgid ¬= files_header.default) then
            info = subword(files_header.orgid,1,2)
          else info = 'id' orgid
          beep_prefix = ''
          if (setting.beep = 'Y') then do
            if (setting.beepcmd ¬= '') then
              interpret "'" || setting.beepcmd || "'"
            beep_prefix = setting.beepchar
          end
          call sendl beep_prefix || hi || 'File' info,
               'arrived at destination' destuser' @ 'destnode || lo
        end /* if notify */
      end /* if reached node */
      else if (index(files.orgid,'Reached') = 0) then do
        files.orgid = 'Currently at node' link', destination',
                      destuser' @ 'destnode
        files_time.orgid = dtime
      end
    end /* file sent across link */
    when (stat = 'ON') & (left(prefix,6) = 'UNABLE') then do
      parse var info 'LINK' link 'TO' destination
      if (index(destination,'(') ¬= 0) then
        parse var destination destnode'('destuser')' .
      else
        parse var destination destnode destuser
      link = strip(link)
      destnode = strip(destnode); destuser = strip(destuser)
      if (files.orgid = '') then
        files_index = files_index orgid
      files.orgid = '* Unable to send on link' link', destination',
                    destuser' @ 'destnode
      files_time.orgid = dtime
    end /* unable to transmit */
    when (stat = 'REJECTED') then do
      if (files.orgid = '') then
        files_index = files_index orgid
      files.orgid = '* Rejected' info
      files_time.orgid = dtime
    end /* if rejected */
    otherwise do
      if (word(rest,find(rest,'FILE')+2) = 'PR') then do
        parse var rest 'FILE' orgid 'PR' priority 'CL',
                       class . 'NA' fn ft .
        orgid = strip(orgid) ; priority = strip(priority)
        if (file_query.orgid ¬= 'FILE_QUERY.'orgid) then  do
          files_header.orgid = fn ft', Priority' priority', Class' class
          drop file_query.orgid
        end
        else call incoming_rscs rest
      end
      else
        call incoming_rscs rest
      return
    end /* otherwise */
  end /* select */
  if (setting.fmsg = 'Y') then do
    oldsetting = setting.jmsg
    setting.jmsg = 'Y'
    call incoming_rscs rest
    setting.jmsg = oldsetting
  end
return /* file_transmission */
 
/* Routine to handle incoming general rscs messages */
incoming_rscs:
  parse arg rscs_msg
  if (setting.jmsg = 'N') then
    return
  rindex = index(translate(rscs_msg),'FROM')
  from = xyzzy_node
  if (rindex ¬= 0) then do
    rscs_msg = substr(rscs_msg,rindex+4)
    parse var rscs_msg from ':' rscs_msg
    from = strip(from) ; rscs_msg = strip(rscs_msg)
  end /* if */
  if left(word(rscs_msg,1),3) = 'DMT' then
    rscs_msg = subword(rscs_msg,2)
  call display '@'from'!('from')' strip(rscs_msg)
return /* incoming_rscs */
 
 
/* Routine to handle the linking to an external HOOK */
call_hook:
  parse arg command
  hookqueue = queued()
  parse var in_packet usernode '!' .
  if (index(command,setting.expandch) ¬= 0) then
      cmd = expand_line(command)
  else
      cmd = command usernode in_msg
  address CMS cmd
  if (rc = 0) then HookReturn = 0 ; else HookReturn = 1
  enable_output = 0
  do while (queued() > hookqueue)
    parse pull line
    call outgoing line
  end
  enable_output = 1
return /* call_hook */
 
 
/*--------------------------------------------------------------------*/
/*    Routine to expand a line (using user/node macro characters)     */
/*--------------------------------------------------------------------*/
Expand_Line:
  parse arg out_line
  new_line = ''
  if (current > 0) then xpacket = talking.current ; else xpacket = '@!'
  parse var in_packet luser '@' lnode '!' lnick
  location = index(out_line,setting.expandch,1)
  do while (location ¬= 0)
    new_line = new_line || left(out_line,location-1)
    comd = substr(out_line,location+1,2) ; xid = ''
    out_line = substr(out_line,location+3)
    if (translate(left(comd,1)) = 'I') & (index(out_line,'.') ¬= 0) &,
       (index('FUNK',translate(substr(comd,2,1))) ¬= 0) then do
      parse var out_line xid '.' out_line
      cmd = 'C' || translate(substr(comd,2))
    end /* if */
      else cmd = translate(comd)
    if (xid = '') then parse var xpacket xuser '@' xnode '!' xnick
      else parse value convert(xid) with xuser '@' xnode '!' xnick
    select
      when (left(comd,1) = setting.expandch) then
        new_line = new_line || comd
      when (cmd = 'CF') then new_line = new_line || xuser'@'xnode
      when (cmd = 'CN') then new_line = new_line || xnode
      when (cmd = 'CU') then new_line = new_line || xuser
      when (cmd = 'CK') then new_line = new_line || xnick
      when (cmd = 'XF') then new_line = new_line||xyzzy_user'@'xyzzy_node
      when (cmd = 'XN') then new_line = new_line || xyzzy_node
      when (cmd = 'XU') then new_line = new_line || xyzzy_user
      when (cmd = 'LF') then new_line = new_line || luser'@'lnode
      when (cmd = 'LU') then new_line = new_line || luser
      when (cmd = 'LN') then new_line = new_line || lnode
      when (cmd = 'LK') then new_line = new_line || lnick
      when (cmd = 'LM') then new_line = new_line || in_msg
      otherwise do
        new_line = new_line || setting.expandch || comd
        if (xid ¬= '') then new_line = new_line || xid || '.'
      end /* otherwise */
    end /* select */
    location = index(out_line,setting.expandch,1)
  end /* while */
  new_line = new_line || out_line
return new_line /* expand_line */
 
 
/*--------------------------------------------------------------------*/
/*      Handler for outgoing messages (messages typed on console)     */
/*--------------------------------------------------------------------*/
Outgoing:
  parse arg out_line
  out_line = strip(out_line,'L')
  if (setting.expand) = 'Y' then out_line = expand_line(out_line)
  select
    when (out_line = '') then do
      call sendl xyzzy_version
    end /* when ='' */
    when (left(out_line,1) = setting.cmdchar) then do
      call parse_command out_line
    end /* when command */
    otherwise do  /* it's a message */
      if (current = nobody_send) then do /* no-one to send to */
        call error 'You are not currently talking to anyone.'
        return
      end /* if not talking to anyone */
      else
      if (current = group_send) then
        call cmd_group out_line
      else
      if (current = cms_send) then
        call cmd_cms out_line
      else
        call send talking.current out_line
    end /* otherwise */
  end /* select */
return /* Outgoing */
 
 
/*--------------------------------------------------------------------*/
/*            Routine to send out a message to someone                */
/*--------------------------------------------------------------------*/
send:
  parse arg send_info send_msg
  parse var send_info send_user '@' send_node '!' send_nick
  OkToWrap = 1 ; OkToPrefix = 1
  special = setting.nowrap || setting.noprefix
  do while (index(special,left(send_msg,1),1) ¬= 0)
    if (left(send_msg,1) = setting.nowrap) then OkToWrap = 0
    if (left(send_msg,1) = setting.noprefix) then OkToPrefix = 0
    send_msg = right(send_msg,length(send_msg)-1)
  end /* while */
  send_prefix = setting.mprefix
  if ( ((index(send_user,'RELAY') ¬= 0) |,
        (index(translate(send_nick),'RELAY') ¬= 0))  &,
        (setting.rprefix = 'Y') ) | ¬(OkToPrefix) then
     send_prefix = ''
  send_msg = strip(send_prefix send_msg)
  if (setting.history ¬= 0) then
    call add_history 'ME' send_info send_msg
  if (translate(left(send_msg,2)) = '/M') then do
    private_header = subword(send_msg,1,2)
    send_msg = subword(send_msg,3)
  end /* if private */
  else                      /* check for relay private msgs */
    private_header = ''
  to_rscs = net_machine
  maxout = setting.outsize
  if (find(routings,send_node) ¬= 0) | (left(routings,1) = '*') then
    do i = words(route.send_node) to 1 by -1
      to_rscs = to_rscs 'CMD' word(route.send_node,i)
    end
  header = send_node send_user private_header
  if (maxout ¬= 0) & (OkToWrap) then
    do while (length(send_msg) > maxout)
      if (maxout <= 10) then start = 1
        else start = maxout - 10
      blank = index(send_msg,' ',start)
      if (blank > maxout) | (blank = 0)
        then blank = maxout
      if (setting.msglocal = 'Y') & (send_node = xyzzy_node) then
        address command cp 'MSG' send_user private_header,
                           substr(send_msg,1,blank)
      else
        address command cp 'SMSG' to_rscs 'MSG',
                           header substr(send_msg,1,blank)
      send_msg = strip(substr(send_msg,blank+1))
    end /* do while long */
  if (setting.msglocal = 'Y') & (send_node = xyzzy_node) then
    address command cp 'MSG' send_user private_header send_msg
  else
    address command cp 'SMSG' to_rscs 'MSG' header send_msg
return /* send */
 
 
/*--------------------------------------------------------------------*/
/*          Routine to display a message to the user (local)          */
/*--------------------------------------------------------------------*/
sendl:
  parse arg sendl_msg
  if (enable_output) then
    if (HookUser = '') then say sendl_msg
      else call send HookUser sendl_msg
return /* sendl */
 
/*--------------------------------------------------------------------*/
/*      Routine to display a message from someone on the screen       */
/*--------------------------------------------------------------------*/
display:
  parse arg display_info display_msg
  display_msg = strip(display_msg)
  if (setting.history ¬= 0) then
    call add_history display_info display_msg
  parse var display_info display_user '@' display_node '!' display_nick
  if ((index(display_user,'RELAY') ¬= 0) |,
      (index(translate(display_nick),'RELAY') ¬= 0))  &,
     (setting.rnick = 'N') then
        header = ''
  else if (display_info = 'NODISPLAY') then
    header = ''
  else if (left(display_nick,4) ¬= 'NONE') &,
          (setting.shownick = 'Y') then
             header = display_nick ':'
  else if (setting.dispform = 'Y') then
    header = '(' || display_node || ')' || display_user ':'
  else
    header = display_user '@' display_node ':'
 
  if ((setting.beep = 'Y') &,
     ((time('E') - old_beep) > setting.beepdelay)) then do
    if (setting.beepcmd ¬= '') then
      interpret "'" || setting.beepcmd || "'"
    if (setting.beepchar ¬= '') then call sendl setting.beepchar
  end /* if */
  old_beep = time('E')
 
  hprefix = ''
  do while (length(display_msg) > setting.insize)
    if (setting.insize <= 10) then start = 1
      else start = setting.insize - 10
    blank = index(display_msg,' ',start)
    if (blank > setting.insize) | (blank = 0) then blank = setting.insize
    call disp_msg substr(display_msg,1,blank)
    display_msg = strip(substr(display_msg,blank+1))
    hprefix = ' >'
  end /* do */
  call disp_msg display_msg
return /* display */
 
/* Used by display to actually show message */
disp_msg:
  parse arg msg
  if (header ¬= '') then front = header || hprefix
    else front = strip(hprefix)
  if (front ¬= '') then call sendl hi || front || lo || msg
    else call sendl msg
return
 
/* routine to add another line to the history saved */
add_history:
  parse arg argument
  if (history_saved < setting.history) then
    history_saved = history_saved + 1
  else do
    drop history.history_base
    history_base = history_base + 1
  end /* else */
  temp = history_base + history_saved
  history.temp = argument
return /* add_history */
 
/*--------------------------------------------------------------------*/
/*      Routine to find a name packet in an array of name packets     */
/*--------------------------------------------------------------------*/
locate:
  parse arg find_type find_item
  upper find_type
  index = 1; found = 0
  select
    when (find_type = 'TALKING') then do
      do while (index <= num_talking) & (found = 0)
        flocate = index(talking.index,'!')
        if translate(left(talking.index,flocate-1)) =,
           translate(left(find_item,flocate-1))
          then found = index
        else index = index + 1
      end
    end
    when (find_type = 'IGNORING') then do
      do while (index <= num_ignoring) & (found = 0)
        flocate = index(ignoring.index,'*')
        if (flocate = 0) then flocate = index(ignoring.index,'!')
        if translate(left(ignoring.index,flocate-1)) =,
           translate(left(find_item,flocate-1))
          then found = index
        else index = index + 1
      end
    end
    otherwise nop
  end /* select */
return found /* locate */
 
 
/*--------------------------------------------------------------------*/
/*     Routine to add a new name packet into the specified name set   */
/*--------------------------------------------------------------------*/
add:
  parse arg add_type add_item
  string = 'num_'add_type '= num_'add_type '+ 1'
  interpret string
  string = add_type'.num_'add_type '= add_item'
  interpret string
return /* add */
 
 
/*--------------------------------------------------------------------*/
/*     Routine to delete a name packet from the specified name set    */
/*--------------------------------------------------------------------*/
delete:
  parse arg del_type del_item
  string = 'del_num = num_'del_type
  interpret string
  spot = locate(del_type del_item)
  if (spot ¬= 0) then do
    do index = spot to del_num
      string = del_type'.'index '=' del_type'.'index+1
      interpret string
    end /* do index */
    string = 'num_'del_type '= num_'del_type '- 1'
    interpret string
    convert_cache = ''
  end /* if */
return /* delete */
 
 
/*--------------------------------------------------------------------*/
/*         Routine to expand a packet into a displayable line         */
/*--------------------------------------------------------------------*/
expand:
  parse arg exp_packet
  if (left(exp_packet,10) = 'TALKING.'group_send) then
    exp_return = 'All defined users'
  else if (left(exp_packet,12) = 'TALKING.'nobody_send) then
    exp_return = 'No defined user'
  else if (left(exp_packet,10) = 'TALKING.'cms_send) then
    exp_return = 'CMS (all msgs are cms commands)'
  else do
    elocate = index(exp_packet,'*')
    if (elocate ¬= 0) then do
      exp_return = 'All users with ids beginning in',
                   substr(exp_packet,1,elocate-1)
    end /* if */
    else do
      parse var exp_packet user '@' node '!' nick
      if (nick ¬= 'NONE') then suffix = ' ('nick')'; else suffix = ''
      exp_return = user '@' node suffix
    end /* else */
  end /* else if defined */
return exp_return /* expand_packet */
 
 
/*--------------------------------------------------------------------*/
/*          Handler for confusing messages from WAKEUP                */
/*--------------------------------------------------------------------*/
confused:
  arg confused_line
  call warning 'Invalid return from WAKEUP:' confused_line
return /* confused */
 
/*--------------------------------------------------------------------*/
/*               Parser for program (.) commands                      */
/*--------------------------------------------------------------------*/
parse_command:
  parse arg comnd arguments
  comnd = substr(comnd,2)
  pcomnd = comnd
  parguments = arguments
  if (translate(word(arguments,1)) = 'AT') & (words(arguments > 1)) &,
     (index(comnd,'@') = 0) then do
    pcomnd = comnd'@'word(arguments,2)
    parguments = subword(arguments,3)
  end /* if */
  upper comnd
  if (abbrev('XYZZY',comnd,1)) & (debug_mode ¬= 0) then do
    call cmd_xyzzy arguments ; return
  end
  parse value convert(pcomnd) with puser '@' pnode '!' pnick
  if (puser ¬= 'ERROR') &,
     ((pnick ¬= 'NONE') |,
      (pnode ¬= xyzzy_node) |,
      (index(pcomnd,'@') ¬= 0) |,
      (datatype(pcomnd) = 'NUM') |,
      (match_command(comnd) = 'NONE')),
  then do
    if parguments = '' then comnd = 'SWITCH'
    else comnd = 'SEND'
    arguments = pcomnd parguments
  end /* if .id */
  routine = match_command(comnd)
  if (routine ¬= 'NONE') then do
    string = 'call cmd_'routine 'arguments'
    interpret string
  end /* if */
  else
    call error 'Invalid command:' comnd
return /* parse_command */
 
 
/* Routine to return the variable command set to the matched command */
/* or equal to 'NONE' if no command match was found                  */
match_command:
  arg match_comnd
  schar = left(match_comnd,1)
  if cmd_index.schar = 'CMD_INDEX.'schar
    then return 'NONE'
  else index = cmd_index.schar
  found = 0
  do while (cmd.index ¬= "CMD."index) & (¬found)
    command = cmd.index
    min_char=verify(command,alphacaps)-1
    if min_char=-1 then min_char=length(command)
    ok_abbrev=abbrev(translate(command),match_comnd,min_char)
    if (ok_abbrev) then
      found = 1
    index=index+1
  end /* do */
  if (¬found) then return 'NONE'
else
return command
 
 
/* Debugging command - not referenced in HELP */
cmd_xyzzy:
  parse arg line
  if (line = '') then
    call sendl 'XYZZY Debugging - Syntax: XYZZY (Rexx Statement)'
  else do
    signal off syntax
    interpret line
    signal on syntax
  end
return /* cmd_xyzzy */
 
 
/* Exit back to CMS */
cmd_exit:     /* exit and stop are same commands.. also come here */
cmd_stop:     /* upon program interrupt (halt:)                   */
cmd_qtalk:
cmd_quit:
halt:
  if (ignore_logged) then do
    call sendl 'Note: You have recent messages that have been ignored.'
    call sendl '      They have been saved in XYZZY IGNLOG A0'
  end /* if ignored msgs */
  parse value diag('08','QUERY VIRTUAL CONSOLE'),
              with 'TERM' status .
  if right(status,1) = '15'x then status = left(status,length(status)-1)
  if (status = 'START') then
    call warning 'Your console is still being spooled.'
  call sendl 'XYZZY Terminating. Returning to CMS.'
  'set msg on'
  'set imescape' old_imescape
  'set timer on'    /* since our timer use changes it to REAL */
  if (oldpf.1 ¬= 'OLDPF.1') then do
    'CP SET' oldpf.1  /* restore used PFkeys */
    'CP SET' oldpf.3
  end
  'set cmstype ht'
  'set msg on';  'set wng on'
  'nucxdrop wakeup'
  'state GLOBALV MODULE *'
  saverc = rc
  'set cmstype rt'
  if (saverc = 0) then do
    'globalv select xyzzy purge'
    if (current > 0) then do
      temp = index(talking.current,'!')-1
      if (temp = -1) then temp = length(talking.current)
      parameters = left(talking.current,temp)
      'globalv select xyzzy put parameters'
      'globalv select xyzzy put clock_alarm'
    end /* if */
  end /* if */
  dropbuf 0
  if (datatype(arguments) = 'NUM') then
    exit arguments
  else
    exit 0
return /* cmd_exit - just for completeness */
 
/* general help routine */
cmd_help:
cmd_?:
  arg arguments
  check = match_command(arguments)
  if (check ¬= 'NONE') then do
    index = 1
    do while (cmd.index ¬= check)
      index = index + 1
    end
    call sendl hi || left(cmd.index,10) || lo ' -- ' help.index
    call sendl left('',20) 'Syntax:' syntax.index
    return
  end
  if (arguments = '') then do
    interpret clear_module
    call sendl left('',27) hi 'XYZZY Commands' lo
    call sendl ''
    index = 1; displayed = 0; line = ''
    do while (cmd.index ¬= 'CMD.'index)
      line = line || left(cmd.index,15)
      displayed = displayed + 1
      if (displayed // 5 = 0) then do
        call sendl '     'line ; line = ''
      end
      index = index + 1;
    end
    if (line ¬= '') then call sendl '     'line
    call sendl ''
    call sendl '     Use  HELP * for full listing'
    call sendl '          HELP xxx* for listing of commands starting',
               'with xxx'
    call sendl '          HELP cmd for help on cmd'
    call sendl '     or   HELP IDINFO for information on the valid form',
               'of an id'
    return
  end
  if (abbrev('IDINFO',arguments,2)) then do
    interpret clear_module
    call sendl 'When a command in Xyzzy references an "id", any of the',
               'following forms'
    call sendl 'may be used:'
    call sendl ''
    index = 1
    do while (ihelp.index ¬= 'IHELP.'index)
      call sendl '     'ihelp.index
      index = index + 1
    end
    return
  end
  if right(arguments,1) = '*' then
    arguments = left(arguments,length(arguments)-1)
  index = 1; displayed = 0;
  do while (cmd.index ¬= 'CMD.'index)
    if (arguments = '') |,
       (left(translate(cmd.index),length(arguments))=arguments) then do
      if (displayed//8 = 0) then do
        interpret clear_module
        if (arguments = '') then
          call sendl left('',27) hi 'XYZZY Commands' lo
        else
          call sendl left('',20) hi 'XYZZY Commands (like',
                     arguments')' lo
        call sendl ' '
      end
      call sendl hi || left(cmd.index,10) || lo ' -- ' help.index
      call sendl left('',20) 'Syntax:' syntax.index
      displayed = displayed + 1
      if (displayed//8 = 0) & (cmd.index ¬= '?') then do
        call sendl ' '
        call sendl left('',12),
                   hi 'Press ENTER for more or continue typing to end' lo
        pull junk
        if (junk ¬= '') then do
          interpret clear_module
          call outgoing junk
          return
        end
      end /* if bottom of screen */
    end /* if display command */
    index = index + 1
  end /* do while */
  if (displayed = 0) then
    call sendl 'No help available for that command.'
  else
    call sendl '-- End of List --'
return /* help */
 
 
/* routine to expand a routing string into a displayable one */
routing:
  arg node
  out = ''
  if (route.node ¬= 'ROUTE.'node) then do
    do r = words(route.node) to 1 by -1
      out = out || word(route.node,r) || '->'
    end
    return left(out,length(out)-2)
  end
return 'No routing exists.'  /* default - routing */
 
 
/* List users known to the program */
cmd_list:
  arg arg1
  list_talking = 1 ; list_ignoring = 1
  arg1 = left(arg1,1)
  if (arg1 = 'T') then list_ignoring = 0
    else if (arg1 = 'I') then list_talking = 0
  if (list_talking) then do
    if (num_talking = 0) then do
      call sendl 'No users being talked to.'
      if (current = cms_send) then
        call sendl 'All messages are being interpreted as CMS commands'
    end /* if */
    else do
      if (current = group_send) then
        extra = '(Sending messages to all defined users)'
      else if (current = cms_send) then
        extra = '(All messages are being interpreted as CMS commands)'
      else
        extra = '(* = current user)'
      call sendl 'Users being talked to:' extra
      if (left(routings,1) = '*') then
        call sendl '(Default message routing:' routing('*')')'
      do index = 1 to num_talking
        if (index = current) then prefix = hi'*'
          else prefix =' 'lo
        parse var talking.index . '@' unode '!' .
        if (find(routings,unode) ¬= 0) then
          extra = '  Routing:' routing(unode)
        else extra = ''
        call sendl prefix left(index,2) || ') ' expand(talking.index),
                   lo extra
      end /* do */
    end /* else */
  end /* if talking */
  if (list_talking)&(list_ignoring) then call sendl ' '
  if (list_ignoring) then do
    if (setting.ignoreall = 'Y') then call sendl,
      'All users (except those being talked to) are being ignored.'
    else
    if (num_ignoring = 0) then call sendl 'No users being ignored.'
    else do
      call sendl 'Users being ignored:'
      do index = 1 to num_ignoring
        call sendl '  ' left(index,2) || ') ' expand(ignoring.index)
      end /* do */
    end /* else */
  end /* if ignoring */
return /* cmd_list */
 
/* Routine to check that a * wildcard isn't used in an "id" when */
/* the id isn't being used in the ignoring list                  */
check_wildcard:
  arg wild_id
  if (index(wild_id,'*') ¬= 0) then
    return 1
return 0 /* check_wildcard */
 
/* Routine to add a new user to list */
cmd_add:
  parse arg arguments
  new_packet = convert(arguments)
  location = locate('talking' new_packet)
  if (new_packet = 'ERROR') | (check_wildcard(arguments)) then
    call error 'Illegal id specified during Add.'
  else if (location ¬= 0) then do
    call error 'Id already in list as #'location'.'
  end /* else */
  else do
    call add 'talking' new_packet
    call sendl 'Added:' num_talking || ')' expand(new_packet)
    call check_other 'ignoring' new_packet
  end /* else */
return /* cmd_add */
 
 
bump_current:
  arg blocation
  if (blocation = current) then do
    call sendl 'The person you were talking to is no longer in',
               'the talking list.'
    if (num_talking >= 1) then do
      current = 1
      call sendl 'Your current user has been reset to:',
                 expand(talking.current)
    end  /* if */
    else do
      current = nobody_send
      call sendl 'You are no longer talking to anyone.'
    end /* else */
  end /* if deleted current */
  if (blocation < current) then  /* possibly adjust current */
    current = current - 1
return /* bump_current */
 
check_other:
  parse arg type check_packet
  if (type = 'ignoring') then do
    extra1 = 'talk to' ; extra2 = 'ignoring'
  end /* if */
  else do
    extra1 = 'ignore' ; extra2 = 'talking to'
  end /* else */
  clocation = locate(type check_packet)
  if (clocation ¬= 0) then do
    call delete type check_packet
    call sendl 'Since you''ve decided to' extra1 expand(check_packet)
    call sendl 'who you are also' extra2', I''ve removed the user from',
               'the' type 'list.'
    if (type = 'talking') then
      call bump_current clocation
  end /* if */
return /* check_ignore */
 
 
/* Routine to delete a person from the list */
cmd_delete:
  arg arguments
  if (arguments = '*') then do
    num_talking = 0
    call sendl 'You are no longer talking to anyone.'
    current = nobody_send
    return
  end /* if */
  del_packet = convert(arguments)
  if (del_packet = 'ERROR') then do
    call error 'Invalid id in DELETE command.'
    return
  end /* if */
  location = locate('talking' del_packet)
  if (location = 0) then do
    call error 'Specified id not in list.'
    return
  end /* if */
  call delete 'talking' del_packet
  call sendl expand(del_packet) 'has been removed from the talking list.'
  call bump_current location
return /* cmd_delete */
 
 
/* function to check if a given string is a valid setting abbrev */
check_setting:
  arg check_option
  check_index = 1 ; check_found = 0
  do while (check_index <= words(settings)) & (¬check_found)
    cset = word(settings,check_index)
    min_char=verify(cset,alphacaps)-1
    if min_char=-1 then min_char=length(cset)
    ok_abbrev=abbrev(translate(cset),check_option,min_char)
    if (ok_abbrev) then
      check_found=1
    check_index = check_index+1
  end /* do */
  if ¬check_found then return 'ERROR'
return cset
 
 
/* Routine to convert setting into displayable form */
convert_setting:
  arg setting
  select
    when (settype.setting = 'Y') then
      if (setting.setting = 'Y') then cvt_value = 'Yes'
        else cvt_value = 'No'
    when (settype.setting = 'N') then
      cvt_value = setting.setting
    when (settype.setting = 'C') then
      if (verify(setting.setting,xrange('00'x,'3F'x),'M') ¬= 0)
        then cvt_value = "'" || c2x(setting.setting) || "'x"
      else
        cvt_value = "'" || setting.setting || "'"
    otherwise nop
  end /* select */
return cvt_value
 
 
/* Procedure to display the current settings */
cmd_set:
  parse arg option opt_value '=' rest
  if (option = '') then do
    call cmd_show
    return
  end
  if (opt_value = '') & (rest ¬= '') then opt_value = rest
  opt_value = strip(opt_value)
  new_value = translate(space(opt_value,0))
  option = strip(option)
  if (translate(option) = 'DEBUG') then do
    debug_mode = new_value
    return
  end
  set = check_setting(option)
  if (set = 'ERROR') then do
    call error 'Invalid option in SET command:' option
    return
  end /* if */
  option = translate(set)
  invalid = 1
  select
    when (settype.option = 'Y') & ¬( abbrev('YES',new_value,1) |,
         abbrev('NO',new_value,1) | abbrev('ON',new_value,2) |,
         abbrev('OFF',new_value,2) ) then
      call error 'Invalid setting.  Yes/No or ON/OFF required.'
    when (settype.option = 'N') & ¬(datatype(new_value,'W')) then
      call error 'Invalid setting.  Numeric value required.'
    when (settype.option = 'C') & (right(new_value,1) = 'X') then do
      if ¬(datatype(left(new_value,length(new_value)-1),'X')) then
        call error 'Invalid hexadecimal string.'
      else invalid = 0
    end
    otherwise invalid = 0
  end /* select */
  if invalid then return
  select    /* now set the values */
    when (settype.option = 'Y') then do
      if (abbrev('YES',new_value,1)) | (abbrev('ON',new_value,2)) then
        new_value = 'Y'
      else
      if (abbrev('NO',new_value,1)) | (abbrev('OFF',new_value,2)) then
        new_value = 'N'
    end /* when */
    when ((settype.option = 'C') & (right(new_value,1) = 'X')) then do
      new_value = space(new_value,0)
      new_value = x2c(left(new_value,length(new_value)-1))
    end
    otherwise new_value = opt_value
  end /* select */
  setting.option = new_value
  call sendl 'Option' option 'set to' convert_setting(option)'.'
  if (option = 'HIGH') then hi = setting.high
  if (option = 'LOW') then lo = setting.low
return /* cmd_set */
 
 
/* Routine to query a setting */
cmd_show:
cmd_qsetting:
  arg options
  if (options ¬= '') & (right(options,1) ¬= '*') then do
    set = check_setting(options)
    if (set = 'ERROR') then
      options = options'*'
    else do
      option = translate(set)
      call sendl 'Current value for' option 'setting =',
                 convert_setting(option)
      return
    end
  end  /* if */
  if (right(options,1) = '*') then
    options = left(options,length(options)-1)
  displayed = 0;
  do index = 1 to words(settings)
    cur_set = word(settings,index)
    if (arguments = '') |,
       (left(translate(cur_set),length(options)) = options) then do
      if (displayed//16 = 0) then do
        interpret clear_module
        if (options = '') then
          call sendl left('',27) hi 'XYZZY Settings' lo
        else
          call sendl left('',20) hi 'XYZZY Settings (like',
                     options')' lo
        call sendl ' '
      end
      cur_index = translate(cur_set)
      cur_sethelp = sethelp.cur_index
      cur_value = convert_setting(cur_index)
      if (length(cur_value) <= 12) then
        call sendl '('left(cur_set,10)')',
                   left(cur_sethelp,52,'.') || hi || cur_value || lo
      else do
        call sendl '('left(cur_set,10)')' left(cur_sethelp,52,'.')
        call sendl left('',14) 'Value:' || hi ||,
                   left(cur_value,53) || lo
        cur_value = substr(cur_value,54)
        displayed = displayed + 1
        do while (cur_value ¬= '')
          call sendl left('',21) || hi || left(cur_value,53) || lo
          cur_value = substr(cur_value,54)
          displayed = displayed + 1
        end
        if (displayed//16 = 0) then displayed = displayed - 1
      end
      displayed = displayed + 1
      if (displayed//16 = 0) then do
        call sendl ' '
        call sendl left('',12),
                   hi 'Press ENTER for more or continue typing to end' lo
        pull junk
        if (junk ¬= '') then do
          interpret clear_module
          call outgoing junk
          return
        end
      end /* if bottom of screen */
    end /* if display command */
  end /* do i */
  if (displayed = 0) then
    call sendl 'No matching settings found.'
  else
    call sendl '-- End of List --'
return /* cmd_qsetting */
 
 
/* Routine to switch current user to another user */
cmd_switch:
  parse arg arguments
  switch_packet = convert(arguments)
  if (switch_packet = 'ERROR') | (check_wildcard(arguments)) then do
    call error 'Invalid id in SWITCH.'
    return
  end /* if error */
  location = locate('talking' switch_packet)
  if (location = 0) then do
    call add 'talking' switch_packet
    location = num_talking
  end
  else
    talking.location = switch_packet
  if (location ¬= current) then do
    call sendl 'Switching to' location || ')' expand(switch_packet)
    current = location
    call check_other 'ignoring' switch_packet
  end
  else call sendl 'You are already talking to',
                  location || ')' expand(switch_packet)
return /* cmd_switch */
 
/* Routine to send a message to a user other than current */
cmd_send:
  parse arg send_to send_msg
  if (translate(word(send_msg,1)) = 'AT') & (words(send_msg > 1)) &,
     (index(send_to,'@') = 0) then do
    send_to = send_to'@'word(send_msg,2)
    send_msg = subword(send_msg,3)
  end /* if */
  if (send_msg = '') then do
    call error 'No message specified in SEND.'
    return
  end
  parse var send_to send_to '!' temp  /* ignore temporary nicknames */
  if (temp ¬= '') then note = '     (temporary nickname ignored)'
    else note = ''
  send_packet = convert(send_to)
  if (send_packet = 'ERROR') | (check_wildcard(send_to)) then do
    call error 'Invalid id in SEND.'
    return
  end
  call send send_packet send_msg
  if (setting.notify = 'Y') then
    call sendl 'Message sent to' expand(send_packet) note
return /* cmd_send */
 
/* Routine to add a new user to the ignoring list */
cmd_ignore:
  parse arg arguments
  if (arguments='*') then do
    setting.ignoreall = 'Y'
    call sendl 'Now ignoring all users not in talking list.'
    return
  end /* if */
  if (index(arguments,'*') ¬= 0) then
    new_packet = translate(arguments)
  else
    new_packet = convert(arguments)
  parse var new_packet user '@' node '!' nick
  location = locate('ignoring' new_packet)
  if (new_packet = 'ERROR') then
    call error 'Illegal id specified during IGNORE.'
  else if (location ¬= 0) then
    call error 'Id already in list as #'location'.'
  else if (user = xyzzy_user) & (node = xyzzy_node) then
    call ignore_yourself  /* ha ha ha ha */
  else do
    call add 'ignoring' new_packet
    call sendl 'Now Ignoring:' expand(new_packet)
    call check_other 'talking' new_packet
  end /* else */
return /* cmd_ignore */
 
/* Routine for people who actually want to ignore themselves :-) */
ignore_yourself:
  call sendl 'Well, I think ignoring yourself is stupid, but if it''s'
  call sendl 'what you really want, well then... ok - you got it!'
  ignore_done = 0
  do until (ignore_done)
    ignore_index = 1
    do until (ignore_index > 6)
      'wakeup +00:00:30 (cons iucvmsg quiet'
      msgtype = rc
      if msgtype = clockend then iterate
      parse pull line
      select
        when (msgtype = console) then
          ignore_index = (ignore_index + 1)
        when (msgtype = normal) then
          call Incoming line
        otherwise
         call Confused line
      end /* select */
    end /* do */
    call sendl 'I''m getting lonely.. you still want me to ignore you?'
    pull answer
    if abbrev('NO',translate(answer),1) then ignore_done = 1
      else ignore_done = 0
  end /* do */
  call sendl 'Ah, finally come to your senses... good.. now let''s get'
  call sendl 'back to the matter at hand.. chatting!'
return /* ignore_yourself */
 
/* Routine to delete a person from the ignoring list */
cmd_noignore:
  arg arguments
  if (arguments = '*') then do
    setting.ignoreall = 'N'
    num_ignoring = 0
    call sendl 'No longer ignoring any users.'
    return
  end /* if */
  if (datatype(arguments) = 'NUM') then arguments = -arguments
  del_packet = convert(arguments)
  if (del_packet = 'ERROR') then do
    call error 'Invalid id in NOIGNORE command.'
    return
  end /* if */
  location = locate('ignoring' del_packet)
  if (location = 0) then do
    call error 'Specified id not in list.'
    return
  end /* if */
  call delete 'ignoring' del_packet
  call sendl expand(del_packet) 'is no longer being ignored.'
return /* cmd_noignore */
 
/* routine to allow the execution of CMS commands */
cmd_dcl:
cmd_cms:
  parse arg arguments
  if (arguments = '') then do
    current = -1
    call sendl 'All messages are now interpreted as CMS commands.'
    return
  end /* if */
  makebuf
  newbuf = rc
  'set imescape' old_imescape
  address cms arguments
  if (rc > 0) then extra = '('right(rc,5,'0')')'
    else if (rc < 0) then extra = '('rc')'
      else extra = ''
  'set cmstype rt'
  'set imescape !'
  'finis * * *'
  call sendl '(Xyzzy) R'extra';'
  dropbuf newbuf
  convert_cache = ''    /* in case mods were made */
return /* cmd_cms */
 
/* routine to allow the execution of CP commands */
cmd_cp:
  arg arguments
  makebuf
  newbuf = rc
  'set imescape' old_imescape
  address command cp arguments
  if (rc > 0) then extra = '('right(rc,5,'0')')'
    else if (rc < 0) then extra = '('rc')'
     else extra = ''
  'set cmstype rt'
  'set imescape !'
  call sendl '(Xyzzy) R'extra';'
  dropbuf newbuf
  convert_cache = ''    /* in case mods were made */
return /* cmd_cp */
 
/* routine to add another line to the history saved */
add_history:
  parse arg argument
  if (history_saved < setting.history) then
    history_saved = history_saved + 1
  else do
    drop history.history_base
    history_base = history_base + 1
  end /* else */
  temp = history_base + history_saved
  history.temp = argument
return /* add_history */
 
/* Routine to display a given number of history items */
cmd_history:
  arg argument '(' option ',' modifier
  all = 0 ; h_packet = ''
  if (option ¬= '') then do
    if abbrev('ALL',modifier,1) then all = 1
    if (argument = '') then argument = '*'
    if (¬all) then do
      h_packet = convert(option)
      if (h_packet = 'ERROR') then do
        call error 'Invalid id in HISTORY command.'
        return
      end /* if */
      parse var h_packet h_packet '!' .
    end /* if option */
    else
      h_packet = '*'  /* so it doesn't match anything */
  end
  if (argument = '*') then argument = history_saved
  if (datatype(argument)='NUM') & (argument > 0) then do
    if (argument <= history_saved) then
      amount_display = argument
    else
      amount_display = history_saved
  end /* if */
  else do
    if (setting.numhist > history_saved) then
      amount_display = history_saved
    else
      amount_display = setting.numhist
  end /* else */
  call sendl '--------- Message History ---------'
  old_settings = setting.history setting.beep
  setting.history = 0
  setting.beep = 'N'
  top = history_base + history_saved
  do hindex = (top - amount_display + 1) to top
    parse var history.hindex hist_packet hist_msg
    if (hist_packet = 'ME') then do
      parse var hist_msg user '@' node '!' nick hist_msg
      if (h_packet = '') | (h_packet = user'@'node) |,
         ( (all) & (index(translate(hist_msg),option) ¬= 0) ) then do
        if (nick ¬= 'NONE') then to = nick; else to = user'@'node
        call sendl '(to' to')' hist_msg
      end /* if ok to show */
    end /* if */
    else do
      parse var hist_packet check '!' .
      if (h_packet = '') | (h_packet = check) |,
         ( (all) & (index(translate(hist_msg),option) ¬= 0) ) then
        call display hist_packet hist_msg
    end /* else */
  end /* do index */
  call sendl '------- End Message History -------'
  parse var old_settings setting.history setting.beep
return /* cmd_history */
 
/* Routine to display current user */
cmd_who:
  arg arguments   /* ignored */
  call sendl 'Currently sending to:' expand(talking.current)
return /* cmd_who */
 
/* Routine to send out a query on a user */
cmd_query:
  parse arg arguments
  query_packet = convert(arguments)
  if (query_packet = 'ERROR') then do
    call error 'Invalid id specified in QUERY.'
    return
  end /* if */
  parse var query_packet user '@' node '!' nick
  to_rscs = net_machine
  if (find(routings,node) ¬= 0) | (left(routings,1) = '*') then do
    do i = words(route.node) to 1 by -1
      to_rscs = to_rscs 'CMD' word(route.node,i)
    end
  end
  if (node = xyzzy_node) then
    address command cp 'SMSG' net_machine 'CPQ U' user
  else
    address command cp 'SMSG' to_rscs 'CMD' node 'CPQ U' user
  call sendl 'Query sent.'
return /* cmd_query */
 
/* Routine to display the current date and time */
cmd_time:
  arg arguments   /* ignored */
  date = date('S')
  day = right(date,2)
  if (left(day,1) = '0') then day = right(day,1)
  year = left(date,4)
  call sendl date('W') || ',' date('M') day',' year '-',
             convert_time(time())
return /* cmd_time */
 
/* Routine to change a user in the talking list to a new user */
cmd_change:
  parse arg from to
  if (translate(word(to,1)) = 'AT') & (words(to) > 1) then do
    from = from'@'word(to,2)
    to = subword(to,3)
  end /* if */
  if (translate(word(to,2)) = 'AT') & (words(to) > 2) then do
    to = word(to,1)'@'word(to,3)
  end /* if */
  from_packet = convert(from)
  to_packet = convert(to)
  if (from_packet = 'ERROR') then do
    call error 'Invalid id in CHANGE:' from
    return
  end /* if invalid from */
  if (to_packet = 'ERROR') | (check_wildcard(to)) then do
    call error 'Invalid id in CHANGE:' to
    return
  end /* if invalid to */
  findex = locate('talking' from_packet)
  tindex = locate('talking' to_packet)
  if (findex = 0) then do
    call error 'Specified id not in talking list:' from
    return
  end /* if not found */
  if (tindex ¬= 0) & (tindex ¬= findex) then do
    call error 'New id already in talking list:' to
    return
  end /* if to is found */
  talking.findex = to_packet
  call sendl 'Number' findex 'changed to' expand(to_packet)
return /* cmd_change */
 
/* Routine to send out queries for users in your names file */
cmd_namezon:
  arg namezon_node "(" options
  options = translate(options,' ',',-')
  if (find(options,'DSC') ¬= 0) then setting.querydsc = 'Y'
  if (find(options,'NOT') ¬= 0) then setting.querynot = 'Y'
  if (find(options,'LOG') ¬= 0) then setting.querylog = 'Y'
  if (find(options,'NODSC') ¬= 0) then setting.querydsc = 'N'
  if (find(options,'NONOT') ¬= 0) then setting.querynot = 'N'
  if (find(options,'NOLOG') ¬= 0) then setting.querylog = 'N'
  namezon_node = strip(namezon_node,'B')
  if (namezon_node = '') then namezon_node = xyzzy_node
  'set cmstype ht'
  'state' setting.namefile 'names *'
  ret=rc
  'set cmstype rt'
  if (ret ¬= 0) then do
    call error setting.namefile 'NAMES not located on an accessed disk.'
    call error 'NAMEZON command not done.'
    return
  end /* if no names file */
  makebuf
  namezonbuf = rc
  namezqueued = queued()
  'EXECIO * DISKR' setting.namefile 'NAMES * (FINIS'
  if (rc ¬= 0) then do
    call error 'EXECIO error reading names file. Return Code:' rc
    dropbuf namezonbuf
    return
  end /* if error reading names file */
  queries = 0;  line = '';
  do while( queued() > namezqueued)
    pull line
    if (strip(line) ¬= '') then do
      if (queued() > namezqueued) then
        do until (left(translate(rest),5) = ':NICK') |,
                 (queued() = namezqueued)
          pull rest
          rest = strip(rest)
          if (left(translate(rest),5) ¬= ':NICK') then line = line rest
            else push rest   /* place back on stack */
        end
      parse var line ':USERID.' user .
      parse var line ':NODE.' node .
        if (node = '') then node = xyzzy_node
      parse var line ':XYZZY.' xyzopt .
      if (user ¬= '') &,
         (find(xyzopt,'NOQUERY') = 0) &,
         (find(namezon_node,'¬'node) = 0) &,
         ( (find(namezon_node,node) ¬= 0) |,
           (find(namezon_node,'*') ¬= 0) |,
           (find(namezon_node,'ALL') ¬= 0) ) then do
        if (node = xyzzy_node) then
          address command cp 'SMSG' net_machine 'CPQ U' user
        else do
          to_rscs = net_machine
          if (find(routings,node) ¬= 0) | (left(routings,1) = '*') then
            do i = words(route.node) to 1 by -1
              to_rscs = to_rscs 'CMD' word(route.node,i)
            end
          address command cp 'SMSG' to_rscs 'CMD' node 'CPQ U' user
        end
        queries = queries + 1
      end
    end /* if non empty names line */
  end /* do names file */
  dropbuf namezonbuf
  if (queries = 0) then call sendl 'No queries sent.'
    else call sendl queries 'queries sent out.'
return /* cmd_namezon */
 
/* Routine to send an RSCS command to another node */
cmd_cmd:
  arg node command
  if (node = '') | (command = '') then do
    call error 'Missing information in CMD.'
    return
  end /* if */
  to_rscs = net_machine
  if (find(routings,node) ¬= 0) | (left(routings,1) = '*') then do
    do i = words(route.node) to 1 by -1
      to_rscs = to_rscs 'CMD' word(route.node,i)
    end
  end
  if (node = xyzzy_node) then
    address command cp 'SMSG' net_machine command
  else
    address command cp 'SMSG' to_rscs 'CMD' node command
return /* cmd_cmd */
 
/* Routine to send a message to all defined users */
cmd_group:
  parse arg group_msg
  if (group_msg = '') & (num_talking = 0) then do
    call error 'There is no group to talk to as you aren''t talking',
               'to anyone.'
    return
  end /* if */
  if (group_msg = '') then do
    call sendl 'Now sending to all defined users.'
    current = group_send
    return
  end /* if */
  do gindex = 1 to num_talking
    call send talking.gindex group_msg
  end /* do */
  if (setting.group = 'Y') then
    call sendl 'Message sent to all defined users.'
return /* cmd_group */
 
/* Routine to display names file information on a person */
cmd_wi:
cmd_find:
  arg arguments
  wi_packet = convert(arguments)
  if (wi_packet = 'ERROR') then do
    call error 'Invalid id specified in WI.'
    return
  end /* if */
  call sendl '"'arguments'" is' expand(wi_packet)
  'set cmstype ht'
  'state' setting.namefile 'names *'
  saverc = rc
  'set cmstype rt'
  if (saverc ¬= 0) then do
    call sendl '(NAMES file not located on accessed disk)'
    return
  end
  parse var wi_packet user '@' node '!' nick
  makebuf
  whobuf = rc
  whoqueued = queued()
  'namefind :userid' user ':node' node '(stack file' setting.namefile
  if (queued() = whoqueued) then do
    call sendl '(No NAMES file information available)'
    return
  end
  at_top = 1
  do queued() - whoqueued
    parse pull result
    parse var result ':' tag tagval
    tag = translate(left(tag,1))||,
    translate(translate(substr(tag,2)),,
    'abcdefghijklmnopqrstuvwxyz',,
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    if (translate(tag) ¬= 'USERID') & (translate(tag) ¬= 'NODE') &,
       (translate(tag) ¬= 'NICK') |,
       ( (translate(tag) = 'NICK') &,
         (translate(tagval) ¬= translate(nick)) ) then do
      if (at_top) then do
        call sendl 'NAMES file information:' ; at_top = 0;
      end
      call sendl '  ' || hi || left(tag || ":",9) || lo || tagval
    end
  end /* do */
  if (at_top) then call sendl '(No additional NAMES file information)'
  dropbuf whobuf
return /* cmd_wi */
 
/* Routine to handle logging of console I/O to a spool file */
cmd_log:
  arg arguments
  parse value diag('08','QUERY VIRTUAL CONSOLE'),
              with . 'TERM' status .
  if right(status,1) = '15'x then status = left(status,length(status)-1)
  if (arguments = '') then do
    if (status = 'START') then
      call sendl 'Console is currently being spooled.'
    else if (status = 'STOP') then
      call sendl 'Console is not currently being spooled.'
    else
      call sendl 'Unknown console mode:' status
    return
  end /* if */
  select
    when (status = 'START') then do
      if (arguments = 'ON') then
        call sendl 'Console already being spooled.'
      else if (arguments = 'OFF') then do
        parse value time() with hr ':' mn ':' .
        parse value date('U') with mon '/' day '/' year
        sfn = 'XYZ-' || hr || mn
        sft = mon || '-' || day || '-' || year
        call sendl 'Console spooling ended:' date() '-' time()
        address command cp 'SPOOL CONSOLE STOP'
        call sendl 'Saved to reader file:' sfn sft
        address command cp 'CLOSE CONSOLE NAME' sfn sft
      end /* else */
      else
        call sendl 'Invalid option in LOG:' arguments
    end /* when */
    when (status = 'STOP') then do
      if (arguments = 'OFF') then
        call sendl 'Console not being spooled.'
      else if (arguments = 'ON') then do
        address command cp 'SPOOL CONS * START'
        call sendl 'Console spooling begun:' date() '-' time()
      end /* else */
      else
        call sendl 'Invalid option in LOG:' arguments
    end /* when */
    otherwise do
      call sendl 'Unknown console mode in LOG:' status
      call sendl 'LOG command aborted.'
    end /* otherwise */
  end /* select */
return /* cmd_log */
 
/* Routine to hold several lines and send them all at once */
cmd_hold:
  arg arguments
  if (arguments ¬= '') then do
    hold_packet = convert(arguments)
    if (hold_packet = 'ERROR') | (check_wildcard(arguments)) then do
      call error 'Invalid id in HOLD.'
      return
    end /* if */
  end /* if */
  else hold_packet = talking.current
  call sendl 'Sending message to:' expand(hold_packet)
  call sendl 'Enter lines. Enter a blank line to send, or type'
  call sendl '.Q to abort sending the message.'
  call sendl '------------------------------------------------'
  h_index = 1 ; done = 0 ; abort = 0
  do while (¬done)
    parse pull hold_msg.h_index
    if (translate(hold_msg.h_index) = '.Q') |,
       (hold_msg.h_index = '') then
      done = 1
    else
      h_index = h_index + 1
  end /* do */
  if (translate(hold_msg.h_index) ¬= '.Q') then do
    do hold = 1 to (h_index-1)
      if (current = group_send) then
        call cmd_group hold_msg.hold
      else if (current = cms_send) then
        call cmd_cms hold_msg.hold
      else
        call send hold_packet hold_msg.hold
    end /* do */
    call sendl 'Message sent.'
  end /* if-do */
  else call sendl 'Message aborted.'
return /* cmd_hold */
 
 
/* Routine to interpret a set of stored lines as your typing */
cmd_macro:
  arg file '(' moption
  if (file = '') then do
    call error 'No file specified in MACRO.'
    return
  end /* if */
  if (words(file) = 1) then file = file 'XYZZY'
  if (words(file) = 2) then file = file '*'
  'set cmstype ht'
  'state' file
  ret = rc
  'set cmstype rt'
  if (ret ¬= 0) then do
    call error 'Unable to locate' file 'on an accessed disk.'
    return
  end /* if */
  if ¬(abbrev('DISPLAY',moption,1)) then
    enable_output = 0
  makebuf
  macrobuf = rc
  macroqueued = queued()
  'set cmstype ht'
  'execio * diskr' file '(finis'
  ret = rc
  'set cmstype rt'
  if (ret ¬= 0) then do
    call error 'EXECIO Error in reading macro' file '. RetCode:' ret
    return
  end /* if */
  do queued() - macroqueued
    parse pull macro_line
    macro_line = strip(macro_line,'T')
    if left(macro_line,1) ¬= '*' then
      call outgoing macro_line
  end /* do */
  enable_output = 1
  dropbuf macrobuf
  if ¬(abbrev('QUIET',moption,5)) then
    call sendl 'Macro file' file 'executed.'
return /* cmd_macro */
 
/* Routine to handle sending an id file to a user */
cmd_id:
  arg arguments
  if (arguments ¬= '') then do
    if (setting.idfile = '') then do
      call error 'ID file hasn''t been set.  ID command ignored.'
      return
    end
    id_packet = convert(arguments)
    if (id_packet = 'ERROR') | (check_wildcard(arguments)) then do
      call error 'Invalid id in ID command.'
      return
    end /* if */
    'set cmstype ht'
    'STATE' setting.idfile
    ret = rc
    'set cmstype rt'
    if (ret ¬= 0) then do
      call error 'Unable to locate id file' setting.idfile'.'
      return
    end /* if */
    parse var id_packet user '@' node '!' nick
    'SENDFILE' setting.idfile user 'AT' node
    call sendl 'ID file sent.'
  end /* if arguments */
  else call error 'No destination id specified in ID'
return /* cmd_id */
 
 
/* Routine to examine/reset the "alarm" */
cmd_alarm:
  arg new_time
  if (new_time = '') then do
    if (clock_alarm = '') then
      call sendl 'No alarm currently set.'
    else
      call sendl 'Alarm currently set to:' convert_time(clock_alarm)
    return
  end /* if no args */
  if (translate(new_time) = 'RESET') | (translate(new_time) = 'OFF')
   then do
    clock_alarm = ''
    call sendl 'Alarm has been reset.'
    return
  end /* if */
  parse var new_time hour ':' min
  modifier = ''
  if (abbrev('MIDNIGHT',new_time,1)) then do
    hour = 0 ; min = 0; modifier = 'AM'
  end
  if (abbrev('NOON',new_time,1)) then do
    hour = 12; min = 0; modifier = 'PM'
  end
  if (min = '') then do
    min = 0
    position = verify(hour,'0123456789')
    if (position ¬= 0) then do
      min = min || substr(hour,position)
      hour = left(hour,position-1)
    end
  end /* if min */
  position = verify(min,'0123456789')
  if (position ¬= 0) then do
    modifier = strip(substr(min,position))
    min = left(min,position-1)
  end
  if (¬datatype(hour,'W')) | (¬datatype(min,'W')) | (hour < 0) |,
     (hour > 23) | (min < 0) | (min > 59) then do
    call error 'Invalid alarm setting.'
    return
  end
  select
    when (modifier = 'AM') & (hour = 12) then hour = 0
    when (modifier = '') & (hour > 12) then modifier = 'PM'
    when (modifier = '') | (modifier = 'AM') |,
         ( (hour = 12) & ( (modifier = 'N') | (modifier = 'PM') ) )
      then nop
    when (modifier = 'PM') & (hour < 12) then hour = hour + 12
    when (modifier = 'M') & (hour = 12) then hour = 0
    otherwise do
      call error 'Invalid alarm setting.'
      return
    end
  end /* select */
  cur = (hour*100)+min
  now = (left(time(),2)*100) + substr(time(),4,2)
  if ((abs(cur-now) > 1200) | (cur < now)) & (modifier = '') then
    hour = (hour + 12) // 24
  clock_alarm = hour':'min
  call sendl 'Alarm is now set at:' convert_time(clock_alarm)
return /* cmd_alarm */
 
 
/* Routine to display all known file status */
cmd_files:
  arg options qualifier
  if (options = 'RESET') & (qualifier ¬= '') then options = 'CLEAR'
  if (options = 'RESET') & (files_index ¬= '') then do
    new_index = ''
    do i = 1 to words(files_index)
      pos = word(files_index,i)
      if left(files.pos,1) ¬= '*' then
        new_index = new_index pos
      else do
        files.pos = ''
        files_header.pos = ''
        files_time.pos = ''
      end
    end /* do i */
    files_index = new_index
    call sendl 'Files that reached their destination have been removed.'
    return
  end /* if reset */
  if (options = 'CLEAR') & (files_index ¬= '') then do
    result = ''
    do i = 1 to words(files_index)
      pos = word(files_index,i)
      comp = translate(files.pos)
      if (qualifier = '') | (index(comp,qualifier) ¬= 0) |,
         (pos = qualifier) then do
        files.pos = ''
        files_header.pos = ''
        files_time.pos = ''
      end
      else result = result pos
    end
    files_index = result
    if (qualifier = '') then
      call sendl 'All file statistics have been cleared.'
    else
      call sendl 'All files matching "'qualifier'" have been cleared.'
    return
  end
  if (files_index = '') then do
    call sendl 'No statistics available on any transmitted files.'
    return
  end /* if */
  call sendl '----- File Transmission Status -----'
  do i = 1 to words(files_index)
    pos = word(files_index,i)
    comp = translate(files.pos)
    if (options = '') | (index(comp,options) ¬= 0) | (pos = options)
      then do
        first = files_time.pos; second = files.pos
        if (files_header.pos ¬= '') then
          first = files_header.pos files_time.pos
        call sendl 'File' pos ':' first
        if (second ¬= '') then call sendl left('',length(pos)+7) second
      end
  end
  call sendl '---------- End File Status ---------'
return
 
 
/* Routine to add given id to your names file */
cmd_addnick:
  parse arg id '(' full_name ',' notebook
  add_packet = convert(id); upper notebook
  parse var add_packet user '@' node '!' nick
  if (add_packet = 'ERROR') | (right(add_packet,4) = 'NONE') then do
    call error 'Invalid id or missing nickname in ADDNICK.'
    return
  end /* if invalid */
  oldstak = queued()
  'set cmstype ht'
  'namefind :userid' user ':node' node,
           ':nick (stack file' setting.namefile
  ret = rc
  'set cmstype rt'
  if (ret = 0) then do
    pull junk
    call error user'@'node 'is already in your names file as' junk
    return
  end
  'set cmstype ht'; lqueue = queued()
  'listfile' setting.namefile 'NAMES * (l stack'
  ret = rc
  'set cmstype rt'
  if (ret = 0) then do
    pull . . mode . . lines .
    mode = left(mode,1)
    do queued() - lqueue
      pull junk
    end
    'set cmstype ht'
    'execio 1 DISKR' setting.namefile 'NAMES' mode lines '(finis'
    ret = rc
    'set cmstype rt'
    if (ret ¬= 0) then do
      call error 'Error while checking names file.. command aborted.'
      return
    end
    pull lastline
    if strip(lastline) ¬= '' then do
      'set cmstype ht'
      'execio 1 DISKW' setting.namefile 'NAMES' mode '(finis string  '
      ret = rc
      'set cmstype rt'
      if (ret ¬= 0) then do
        call error 'Error while writing to names file..command aborted'
        return
      end
    end /* if needed a blank line */
  end /* if file existed */
    else mode = 'A'   /* create a new names file on disk A */
  line1 = ':nick.'left(nick,8) ':userid.'left(user,8),
          ':node.'left(node,8)
  if (notebook ¬= '') then line1 = line1 ':notebook.'left(notebook,8)
  if (full_name ¬= '') then line2 = left('',14) ':name.'full_name
    else line2 = ''
  'set cmstype ht'
  'execio 1 diskw' setting.namefile 'NAMES' mode '(string' line1
  if (line2 ¬= '') then
    'execio 1 diskw' setting.namefile 'NAMES' mode '(string' line2
  'finis' setting.namefile 'NAMES' mode
  ret=rc
  'set cmstype rt'
  if (ret ¬= 0) then do
    call error 'Error while updating names file.... command aborted.'
    return
  end
  if (full_name ¬= '') then last = '('full_name')'
    else last = ''
  if (notebook ¬= '') then last = last', notebook' notebook
  call sendl user '@' node 'is now in your names file as',
             nick last
return /* cmd_addnick */
 
 
/* Routine to handle the routing of bitnet messages through nodes */
cmd_route:
  arg node option
  option = translate(option,' ','->,.@%;')
  select
    when node = '' then do
      if (routings = '') then call sendl 'No routings in effect.'
      else if (routings = '*') then
        call sendl 'Default message routing:' routing('*')
      else do
        call sendl '----- Routings currently in effect -----'
        do i = 1 to words(routings)
          rindex = word(routings,i)
          if (rindex = '*') then rindex = 'DEFAULT'
          call sendl left(rindex,8) ':' routing(rindex)
        end /* do i */
        call sendl '---------- End of routing list ---------'
      end
    end /* when */
    when (node ¬= '') & (option = '') then
      call sendl 'Routing for' node ':' routing(node)
    when option = 'RESET' then do
      if (node = '*') then do
        routings = '' ; drop route.
        call sendl 'All routings have been reset.'
      end
      else
      if (find(routings,node) ¬= 0) then do
        routings = delword(routings,find(routings,node),1)
        call sendl 'Routing for' node 'removed.'
      end
      else call sendl 'No routing currently exists for' node'.'
    end /* when reset */
    otherwise do
      do i = words(option)-1 to 1 by -1
        option = delword(option,i,1) word(option,i)
      end
      if (node = '*') then do
        routings = '*' ; route. = option
        call sendl 'All nodes routed to' routing('*')
      end
      else do
        route.node = option
        if (find(routings,node) = 0) then routings = routings node
        call sendl 'Routing for' node 'set to:' routing(node)
      end /* else */
    end
  end /* select */
return /* cmd_route */
 
 
/* Handler for external command "hooks" for specific users */
cmd_hooks:
  parse arg htype in_id hcommand
  if (in_id = '') then do
    found = 0
    do x = 1 to words(hook_types)
      index = translate(word(hook_types,x))
      hindex = 'HOOK' || index
      if ( (words(hook_index.hindex) > 0) | (hook.hindex.astx ¬= '') ) &,
        ( (htype = '') |,
          (abbrev(translate(index),translate(htype),1)) ) then do
        call sendl hi || index 'hooks:' || lo
        if (hook.hindex.astx ¬= '') then
          call sendl left('   Default ',20,'.') hook.hindex.astx
        do i = 1 to words(hook_index.hindex)
          index = word(hook_index.hindex,i)
          call sendl left('   'index' ',20,'.') hook.hindex.index
        end
        found = 1
      end /* if */
    end /* do */
    if (¬found) then call sendl 'No external hooks currently defined.'
    return
  end /* if */
 
  if (in_id = '') | (hcommand = '') then do
    call error 'Missing information in HOOK command.'
    call error 'You must specify hook id and command.'
    return
  end
 
  found = 0 ; x = 1
  do while (¬found) & (x <= words(hook_types))
    index = 'HOOK' || translate(word(hook_types,x))
    if abbrev(substr(index,5),translate(htype),1) then do
      found = 1
      if (hook_key.index ¬= 'C') then key = translate(in_id) ; else do
        parse value convert(in_id) with key '!' .
        if (key = 'ERROR') then do
          call error 'Invalid id specified in HOOK:' in_id
          return
        end /* if */
      end /* else */
      if (strip(in_id) = '*') then do
        key = '*' ; info = 'Default' word(hook_types,x) 'hook'
      end
        else info = word(hook_types,x) 'hook for' key
      if (translate(hcommand) ¬= 'RESET') then do
        if (key ¬= '*') & (find(hook_index.index,key) = 0) then
          hook_index.index = hook_index.index key
        hook.index.key = hcommand
        call sendl info 'set to "'hcommand'"'
      end
      else do
        loc = find(hook_index.index,key)
        def = hook.index.key
        if (loc = 0) & (def = '') then do
          call error 'Specified hook not located.'
          return
        end
        if (loc ¬= 0) then
          hook_index.index = delword(hook_index.index,loc)
        hook.index.key = ''
        call sendl info 'has been reset'
      end /* else */
 
    end /* if */
    x = x + 1
  end /* while */
  if (¬found) then call error 'Invalid hook type specified:' htype
return /* cmd_hooks */
 
 
/* Cute addition - kitchen sink */
cmd_sink:
  call sendl 'This is to officially recognize that this program has',
             'everything, including a'
  call sendl left('',27) hi || 'Kitchen Sink' || lo
return /* cmd_sink */
 
 
/* Routine to display the current version of XYZZY */
cmd_version:
  call sendl xyzzy_version
return
 
 
/*--------------------------------------------------------------------*/
/*                  Program Error/Warning handlers                    */
/*--------------------------------------------------------------------*/
Error:
  parse arg errortext
  say '** Error:' errortext
return /* Standard Error */
 
Warning:
  parse arg wngtext
  say '** Warning:' wngtext
return /* Standard Warning */
 
Abort:
  parse arg aborttext
  say '** Fatal Error:' aborttext
  say '   Program terminating.'
  call cmd_exit -1
return /* Kind of worthless, but for completeness... */
 
 
/*--------------------------------------------------------------------*/
/*                       Initialization Routine                       */
/*--------------------------------------------------------------------*/
Initialize:
 
/* Warn and abort if messages are already set to IUCV */
parse value diag('08','QUERY SET') with . msg_setting .
if (index(msg_setting,'IUCV') ¬= 0) then do
  say '** Your messages are already being trapped by another    **'
  say '** program. Please stop that program before using XYZZY. **'
  say '** If there is no other program that should be trapping  **'
  say '** your messages, typing SET MSG ON will turn it off.    **'
  exit
end /* do */
 
/* Set up some constants for the program to use */
conv_count = 0
xyzzy_version = '* XYZZY - Release 2.5 *'
author_user = 'DB3L'
author_node = 'CMUCCVMA'
normal   = 5     /* definitions for return codes from WAKEUP */
console  = 6
clockend = 2
group_send = -2     /* constants used to identify "current user" */
cms_send = -1
nobody_send = -255
debug_mode = 0
alphacaps = '?.ABCDEFGHIJKLMNOPQRSTUVWXYZ'
ignore_logged = 0   /* no messages ignored yet */
old_log_time = 0  /* some settings for GONE portion of program */
old_log_user = ''
old_log_node = ''
enable_output = 1   /* allow command output */
old_time = time('E')   /* used by timemark */
old_beep = old_time    /* used for beeping */
id_file = ''    /* no default id filename */
clock_alarm = ''   /* no alarm set initially */
showed_alarm = 0  /* no we haven't displayed the alarm */
clock_shown = -1  /* we haven't displayed half past or hour times yet */
files_index = ''  /* set up vars for file transmission summary */
files_header.= '* Unidentified *'
files_time. = ''
files. = ''
routings = ''   /* No routings currently in effect */
convert_cache = ''
astx = '*'              /* Set up external hook information */
hook_types = 'LowLevel RSCS Message Talking Ignoring'
hook_key.hooklowlevel = 'C'
hook_key.hookrscs     = ''
hook_key.hookmessage  = 'C'
hook_key.hooktalking  = 'C'
hook_key.hookignoring = 'C'
hook_index. = ''
hook. = ''
HookReturn = 0
HookUser = ''
 
/* Figure out who we are */
"id (stack"
pull xyzzy_user . xyzzy_node . net_machine .
 
 
'query imescape (stack'
pull '=' old_imescape
'set imescape !'
'set cmstype ht'
'state xyzzy ignlog a0'
if (rc = 0) then do
  'state xyzzy ignhist a0'
  if (rc = 0) then 'erase xyzzy ignhist a0'
  'rename xyzzy ignlog a0 xyzzy ignhist a0'
end /* if */
'state vmfclear module *'
if (rc = 0) then clear_module = 'VMFCLEAR'
  else do
    'state clrscrn module *'
    if (rc = 0) then clear_module = 'CLRSCRN'
      else clear_module = ''
  end /* else */
if (clear_module = '') then do
  call abort 'You must have VMFCLEAR or CLRSCRN on an accessed ',
             'disk to run XYZZY.'
end /* if */
'state wakeup module *'
if (rc ¬= 0) then do
  call abort 'You must have WAKEUP on an accessed disk to run XYZZY.'
end /* if */
 
/* Knock out any possible competitors :-) */
'nucxdrop ywakeup'
'nucxdrop iucvtrap'
 
/* In case they screwed with settings */
'set cpconio off'
'set vmconio off'
'set smsg off'
 
/* Install WAKEUP - start IUCV trapping */
'wakeup +00:00:00 (iucvmsg'
'set wng iucv'  /* also trap warnings */
'set cmstype rt'
 
/* Initialize the talking and ignoring arrays */
num_talking  = 0
num_ignoring = 0
 
/* Initialize program "settings" */
settings = 'Beep BEEPCHar BEEPCMd BEEPDelay Clock CMdchar COnvsize'
settings = settings 'Dispform Expand EXPANDCh FIletrack FMsg FNotify'
settings = settings 'Group HIGh History IBMMode IDfile IGNDelay IGNMsg'
settings = settings 'Ignore IGNOREAll INsize Jmsg Logignore LOw'
settings = settings 'MPrefix MSglocal NAmefile NOPrefix NOTify NOWrap'
settings = settings 'NUmhist Outsize Pfkeys QUERYDsc QUERYLog QUERYNot'
settings = settings 'RNick RPrefix SHownick Timemark TIMEDelay'
settings = settings 'XDirectory'
 
setting.beep      = 'N'            ; settype.beep      = 'Y'
setting.beepchar  = ''             ; settype.beepchar  = 'C'
if (xyzzy_node = 'CMUCCVMA') then setting.beepcmd   = 'CP BEEP'
  else setting.beepcmd = ''        ; settype.beepcmd   = 'C'
setting.beepdelay = 1              ; settype.beepdelay = 'N'
setting.clock     = 'N'            ; settype.clock     = 'Y'
setting.cmdchar   = '.'            ; settype.cmdchar   = 'C'
setting.convsize  = 25             ; settype.convsize  = 'N'
setting.dispform  = 'Y'            ; settype.dispform  = 'Y'
setting.expand    = 'N'            ; settype.expand    = 'Y'
setting.expandch  = '$'            ; settype.expandch  = 'C'
setting.filetrack = 'Y'            ; settype.filetrack = 'Y'
setting.fmsg      = 'Y'            ; settype.fmsg      = 'Y'
setting.fnotify   = 'Y'            ; settype.fnotify   = 'Y'
setting.group     = 'Y'            ; settype.group     = 'Y'
setting.high      = '1DE8'x        ; settype.high      = 'C'
  hi = setting.high
setting.history   = 15             ; settype.history   = 'N'
  history_base = 1  ; history_saved = 0
setting.ibmmode   = 'Y'            ; settype.ibmmode   = 'Y'
setting.idfile    = ''             ; settype.idfile    = 'C'
setting.igndelay  = 10             ; settype.igndelay  = 'N'
setting.ignmsg    = ,
 "I'm currently busy, and can't talk now. Your message has been logged."
                                   ; settype.ignmsg    = 'C'
setting.ignore    = 'N'            ; settype.ignore    = 'Y'
setting.ignoreall = 'N'            ; settype.ignoreall = 'Y'
setting.insize    = 65             ; settype.insize    = 'N'
setting.jmsg      = 'Y'            ; settype.jmsg      = 'Y'
setting.logignore = 'Y'            ; settype.logignore = 'Y'
setting.low       = '1D60'x        ; settype.low       = 'C'
  lo = setting.low
setting.mprefix   = ''             ; settype.mprefix   = 'C'
setting.msglocal  = 'N'            ; settype.msglocal  = 'Y'
setting.namefile  = xyzzy_user     ; settype.namefile  = 'C'
setting.noprefix  = ')'            ; settype.noprefix  = 'C'
setting.notify    = 'Y'            ; settype.notify    = 'Y'
setting.nowrap    = '>'            ; settype.nowrap    = 'C'
setting.numhist   = 5              ; settype.numhist   = 'N'
setting.outsize   = 50             ; settype.outsize   = 'N'
setting.pfkeys    = 'Y'            ; settype.pfkeys    = 'Y'
setting.querydsc  = 'Y'            ; settype.querydsc  = 'Y'
setting.querylog  = 'Y'            ; settype.querylog  = 'Y'
setting.querynot  = 'Y'            ; settype.querynot  = 'Y'
setting.rnick     = 'N'            ; settype.rnick     = 'Y'
setting.rprefix   = 'Y'            ; settype.rprefix   = 'Y'
setting.shownick  = 'Y'            ; settype.shownick  = 'Y'
setting.timemark  = 'N'            ; settype.timemark  = 'Y'
setting.timedelay = 1              ; settype.timedelay = 'N'
setting.xdirectory= ''             ; settype.xdirectory= 'C'
 
sethelp.beep      = 'Beep upon display of incoming message'
sethelp.beepchar  = 'Character to use to cause the terminal to beep'
sethelp.beepcmd   = 'Command to issue a console beep (if available)'
sethelp.beepdelay = 'Delay needed for two msgs to cause two beeps (secs)'
sethelp.clock     = 'Should the time be displayed every half hour'
sethelp.cmdchar   = 'Character signifying an XYZZY command'
sethelp.convsize  = 'Size (# of ids) of the convert "cache"'
sethelp.dispform  = 'Standard id display (Y = (node)user, N = user@node)'
sethelp.expand    = 'Should outgoing lines be expanded'
sethelp.expandch  = 'Expansion character for input line expansion'
sethelp.filetrack = 'Whether file messages should be "tracked"'
sethelp.fmsg      = 'Display RSCS file transmission messages'
sethelp.fnotify   = 'Notify when a sent file reaches its destination'
sethelp.group     = 'Display note after messages sent to entire list'
sethelp.high      = 'Characters used to start high intensity'
sethelp.history   = 'Message history logging value (lines logged)'
sethelp.ibmmode   = 'Not used.  For compability with XYZZY-VAX'
sethelp.idfile    = 'The name of the file the ID command should send'
sethelp.igndelay  = 'Incoming msg delay for two ignore msgs to be sent'
sethelp.ignmsg    = 'Message sent to ignored users'
sethelp.ignore    = 'Announce when a message has been ignored'
sethelp.ignoreall = 'Ignore everyone except those being talked to'
sethelp.insize    = 'Incoming message "split" size'
sethelp.jmsg      = 'Display RSCS "junk" messages'
sethelp.logignore = 'Log all messages that are ignored'
sethelp.low       = 'Characters used to end high intensity'
sethelp.mprefix   = 'String to prefix all outgoing messages with'
sethelp.msglocal  = 'Use MSG rather than RSCS for local messages'
sethelp.namefile  = 'NAMES file to use.'
sethelp.noprefix  = 'Character signifying not to use a message prefix'
sethelp.notify    = 'Display user (if not current) receiving messages'
sethelp.nowrap    = 'Character signifying not to split outgoing line'
sethelp.numhist   = 'Default # of history lines to display (in .HISTORY)'
sethelp.outsize   = 'Outgoing RSCS message "split" size'
sethelp.pfkeys    = 'Whether XYZZY should reassign PFkeys 1 and 3'
sethelp.querydsc  = 'Display query returns for disconnected users'
sethelp.querylog  = 'Display query returns for logged in users'
sethelp.querynot  = 'Display query returns for not logged in users'
sethelp.rnick     = 'Display a relay''s user or nickname with messages'
sethelp.rprefix   = 'Ignore message prefix when sending to a relay'
sethelp.shownick  = 'Display nicknames when possible'
sethelp.timemark  = 'Display date and time before incoming messages'
sethelp.timedelay = 'Delay for two msgs to have two time stamps (secs)'
sethelp.xdirectory= 'Not used.  For compability with XYZZY-VAX'
 
/* Set up index array to speed up command searches */
cmd_index.A = 1
cmd_index.C = 4
cmd_index.D = 8
cmd_index.E = 10
cmd_index.F = 11
cmd_index.G = 13
cmd_index.H = 14
cmd_index.I = 18
cmd_index.L = 20
cmd_index.M = 22
cmd_index.N = 23
cmd_index.Q = 25
cmd_index.R = 29
cmd_index.S = 30
cmd_index.T = 36
cmd_index.V = 37
cmd_index.W = 38
cmd_index.? = 40
 
/* Initialize program command array */
cmd.1  = 'Add'      ; syntax.1  = 'Add id'
cmd.2  = 'ADDNick'
  syntax.2  = 'ADDNick id < (Full Name < ,notebook > >'
cmd.3  = 'ALarm'
  syntax.3  = 'ALarm hour:min<AM|PM>|Midnight|Noon|RESET|OFF'
cmd.4  = 'CHange'   ; syntax.4  = 'CHange id newid'
cmd.5  = 'CMD'      ; syntax.5  = 'CMD node rscs_command'
cmd.6  = 'Cms'      ; syntax.6  = 'Cms (nothing) | cms_command'
cmd.7  = 'CP'       ; syntax.7  = 'CP cp_command'
cmd.8  = 'DCl'      ; syntax.8  = 'DCl (nothing) | cms_command'
cmd.9  = 'Delete'   ; syntax.9  = 'Delete id | ''*'''
cmd.10 = 'Exit'     ; syntax.10 = 'Exit (no arguments)'
cmd.11 = 'Files'
  syntax.11 = 'Files (nothing) | RESET | CLEAR | SearchString'
cmd.12 = 'FINd'     ; syntax.12 = 'FINd id'
cmd.13 = 'Group'    ; syntax.13 = 'Group (nothing) | message'
cmd.14 = 'Help'     ; syntax.14 = 'Help (nothing) | (partial command)<*>'
cmd.15 = 'HIstory'
  syntax.15 = 'HIstory (nothing) | # | ''*'' < (id | <string ,ALL> >'
cmd.16 = 'HOLd'     ; syntax.16 = 'HOLd (nothing) | id'
cmd.17 = 'HOOks'    ; syntax.17 = 'HOOks <type <id|*   RESET | command>>'
cmd.18 = 'ID'       ; syntax.18 = 'ID id'
cmd.19 = 'Ignore'   ; syntax.19 = 'Ignore id | ''*'''
cmd.20 = 'List'     ; syntax.20 = 'List (nothing) | ignoring | talking'
cmd.21 = 'LOg'      ; syntax.21 = 'LOg (nothing) | ON | OFF'
cmd.22 = 'MAcro'    ; syntax.22 = 'MAcro filename <(DISPLAY>'
cmd.23 = 'Namezon'
  syntax.23 = 'Namezon (nothing)|node|ALL|* < (<NO>DSC,LOG,NOT >'
cmd.24 = 'NOignore' ; syntax.24 = 'NOignore id | ''*'''
cmd.25 = 'QSetting' ; syntax.25 = 'QSetting (nothing) | (setting)<*>'
cmd.26 = 'QTalk'    ; syntax.26 = 'QTalk (no arguments)'
cmd.27 = 'Query'    ; syntax.27 = 'Query id'
cmd.28 = 'QUIt'     ; syntax.28 = 'QUIt (no arguments)'
cmd.29 = 'Route'
  syntax.29 = 'Route < node | ''*'' < routing | ''RESET'' > >'
cmd.30 = 'Send'     ; syntax.30 = 'Send id message'
cmd.31 = 'SET'
  syntax.31 = 'SET (nothing) | option <=> setting'
cmd.32 = 'SHow'     ; syntax.32 = 'SHow (nothing) | (setting)<*>'
cmd.33 = 'SInk'     ; syntax.33 = 'SInk (no arguments)'
cmd.34 = 'STop'     ; syntax.34 = 'STop (no arguments)'
cmd.35 = 'SWitch'   ; syntax.35 = 'SWitch id'
cmd.36 = 'Time'     ; syntax.36 = 'Time (no arguments)'
cmd.37 = 'Version'  ; syntax.37 = 'Version (no arguments)'
cmd.38 = 'Who'      ; syntax.38 = 'Who (no arguments)'
cmd.39 = 'WI'       ; syntax.39 = 'WI id'
cmd.40 = '?'        ; syntax.40 = '? (nothing) | (partial command)<*>'
 
help.1  = 'Add a new user to the list of users known to the program'
help.2  = 'Add person to names file, optionally with full name/notebook'
help.3  = 'Set/Examine/Reset time when XYZZY should notify you.'
help.4  = 'Change an item in the talking list to another person'
help.5  = 'Send an RSCS command to the specified node'
help.6  = 'Execute a CMS command from within XYZZY'
help.7  = 'Execute a CP command from within XYZZY'
help.8  = 'Execute a CMS command (for compatibility with XYZZY-VAX)'
help.9  = 'Delete a user from the "talking" list. * = delete everyone'
help.10 = 'Exit back to CMS'
help.11 = 'Display status of sent files.'
help.12 = '(same as WI command)'
help.13 = 'Send a message to all defined users'
help.14 = 'Display help on specified command(s)'
help.15 = 'Display all or selected portions of message history'
help.16 = 'Hold several lines and send them as a single message'
help.17 = 'External hooks (LowLevel,RSCS,Message,Talking,Ignoring)'
help.18 = 'Send "id file" to a user. IDFILE setting specifies filename.'
help.19 = 'Add user to ignore list (* = all users not in talk list)'
help.20 = 'List users currently known to the program'
help.21 = 'Controls the spooling of console I/O to reader file'
help.22 = 'Interprets lines in file as if you had typed them'
help.23 = 'Sends out queries for names file entries for the given node'
help.24 = 'Remove user from ignore list (* = remove all ignorees)'
help.25 = 'Shows setting values (same as the SHOW command)'
help.26 = '(same as EXIT command - for compatability with TALKTO)'
help.27 = 'Sends a query to see if a specific user is logged on'
help.28 = '(same as EXIT command)'
help.29 = 'Specify node routine for messages'
help.30 = 'Send a message to specified user'
help.31 = 'Allows you to change the program "settings"'
help.32 = 'Shows values of all settings, or just specified ones'
help.33 = 'Xyzzy has it all.'
help.34 = '(Same as EXIT command - for compatability with TALK)'
help.35 = 'Switch to a different current user'
help.36 = 'Displays the current date and time'
help.37 = 'Displays the current version of xyzzy'
help.38 = 'Display name of person to whom messages are currently sent'
help.39 = 'Displays names file information on a person (WI = WhoIs)'
help.40 = '(Same as HELP command)'
 
 
ihelp.1='Nickname      - Nickname which is found in your NAMES file'
ihelp.2='                or a local nickname in use within XYZZY'
ihelp.3='User          - User at your local node or a user who is in'
ihelp.4='                the XYZZY "talking" list'
ihelp.5='User@Node     - User at a remote node as specified'
ihelp.6='User AT Node  - Same as User@Node except using the word "AT"'
ihelp.7='#             - Number of person in the XYZZY "talking" list'
ihelp.8=''
ihelp.9='Any of the above forms may be optionally followed by "!nick"'
ihelp.10='where nick is a temporary nickname for use within XYZZY.'
 
 
/* Parse initial arguments */
if (parameters = '') then do
  'set cmstype ht'
  'state globalv module *'
  if (rc = 0) then
    'globalv select xyzzy get parameters'
    'globalv select xyzzy get clock_alarm'
  'set cmstype rt'
end /* if */
if (parameters = '') then do
  call sendl 'Please enter nickname or (user@node) to talk to:'
  parse pull parameters
  if (parameters = '') then call cmd_exit
end /* if */
cur_packet = convert(parameters) /* translate into user,node,nickname */
if cur_packet = 'ERROR' then
  call abort 'Invalid id specified.'
call add 'talking' cur_packet     /* insert into list of people */
current = 1  /* start talking to primary person */
interpret clear_module
 
/* Process profile if present */
set cmstype ht
"state PROFILE XYZZY *"
ret = rc
set cmstype rt
if (ret = 0) then do
  call cmd_macro 'PROFILE (QUIET'
end /* if profile */
 
/* Warn about non-existent names file */
'set cmstype ht'
"state" setting.namefile "names *"
ret = rc
'set cmstype rt'
if (ret ¬= 0) then do
  call sendl 'WARNING:' setting.namefile,
             'NAMES was not located on an accessed disk.'
  call sendl '         Until a names file is created, or the NAMEFILE',
             'setting changed to'
  call sendl '         refer to a different name file, only temporary',
             'nicknames may be used.'
  call sendl ''
end /* if no names file */
 
/* Check on the PFkeys we're gonna change */
if (setting.pfkeys = 'Y') then do
  'execio * CP (string QUERY PF1'
  pull oldpf.1; if right(oldpf.1,9) = 'UNDEFINED' then oldpf.1 = 'PF1'
  'execio * CP (string QUERY PF3'
  pull oldpf.3; if right(oldpf.3,9) = 'UNDEFINED' then oldpf.3 = 'PF3'
  /* now set them to be HELP (cms version) and EXIT */
  'set cmstype ht'
  'state XYZZY HELPCMS *'
  ret = rc
  'set cmstype rt'
  if (ret = 0) then 'CP SET PF1 IMMED .CMS HELP XYZZY'
    else 'CP SET PF1 IMMED .HELP'
  'CP SET PF3 IMMED .EXIT'
end /* pfkeys */
 
/* All set up... start talking */
call sendl left('',trunc((80-length(xyzzy_version)+2)/2)) ||,
                hi || xyzzy_version || lo
intro_line = 'Created by David Bolen (DB3L@CMUCCVMA)  -  ' ||,
             'Type .HELP for command list'
call sendl left('',trunc((80-length(intro_line))/2)) || intro_line
call sendl left('',80,'-')
call sendl 'Sending to:' expand(talking.current)
return /* Initialize */
 
 
/*--------------------------------------------------------------------*/
/*                     Handler for program bugs                       */
/*--------------------------------------------------------------------*/
syntax:
  err_rc = rc
  err_line = sigl
  'spool pun close'
  'spool pun *'
  punch = 'EXECIO 1 PUNCH (STRING'
  punch '----------------- XYZZY Bug Report -------------------'
  punch ' '
  punch date() time() '-' xyzzy_user '@' xyzzy_node
  punch 'XYZZY version:' xyzzy_version
  punch ' '
  punch 'Error:' err_rc 'in line' err_line
  punch '      ' errortext(err_rc)
  punch ' '
  punch '------------------------------------------------------'
  punch ' '
  punch 'Please send this bug report to' author_user'@'author_node
  punch 'if it is not the result of local modifications.'
  'close punch name XYZZY BUGRPT'
  'spool pun OFF'
  say ''
  say '***** Syntax error in XYZZY! *****'
  say ''
  say 'A bug report has just been placed in your reader.  If this error'
  say 'is not the result of a local modification, please send the bug'
  say 'report to' author_user'@'author_node
  say ''
  signal off syntax   /* prevent looping */
  call cmd_exit -1
return /* syntax - never gets this far */
 
 
/*--------------------------------------------------------------------*/
/*  Program History                                                   */
/*       1.0   -   March 15, 1986 - Initial Program Release           */
/*       1.1   -   March 16, 1986 - Modified to use IUCVTRAP          */
/*       1.2   -   March 18, 1986 - Watches for MSG already IUCV      */
/*       1.3   -   March 19, 1986 - Fix to work on nodes which        */
/*                                  have eliminated RSCS DMT msgs     */
/*       1.4   -   March 20, 1986 - Added "missing" .CP code          */
/*       1.5   -   April  1, 1986 - bad "NOT ACCEPTED" problem with   */
/*                                  IUCVTRAP - so back to WAKEUP      */
/*       1.6   -   April  5, 1986 - Many minor changes. Also fixed    */
/*                                  subtle problem with wrapping of   */
/*                                  incoming/outgoing messages. The   */
/*                                  profile handler also fixed. Also  */
/*                                  added new command .MACRO          */
/*       1.7   -   April 12, 1986 - Fixed problem with HOLD command   */
/*                                  when in CMS or GROUP mode. New    */
/*                                  commands ID and NOWRAP added, as  */
/*                                  well as changes to HISTORY cmd.   */
/*                                  Many minor changes made for       */
/*                                  aesthetic reasons.                */
/*       2.0   -   April 26, 1986 - ** New IUCV trap: XYZIUCV **      */
/*                                  Fix to ignore_yourself routine,   */
/*                                  and to problem with msgs from     */
/*                                  local users with all numeric ids. */
/*                                  Added ALARM command, and CLOCK    */
/*                                  setting. Also allowed you to      */
/*                                  to specify id using userid of     */
/*                                  person in the talking list.       */
/*       2.1   -   May 7, 1986    - New command QSETTING and a new    */
/*                                  setting MSGLOCAL.  Fixed msgs at  */
/*                                  CLVM and the LOG problems at some */
/*                                  strange nodes.                    */
/*       2.2   -   Sept. 20, 1986 - Many changes. Most important were */
/*                                  the watching of file transmission */
/*                                  messages, temporary nicknames,    */
/*                                  new cmds: ADDNICK and FILES - PF  */
/*                                  keys 1=help/3=exit - new settings */
/*                                  FNOTIFY, FMSG/JMSG. Mods to QSET, */
/*                                  SET, HISTORY, CHANGE, SWITCH, ID. */
/*                                  Major help file mods as well.     */
/*                                                                    */
/*       2.3   -   Oct. 26, 1986  - PFkeys are now set dependent on   */
/*                                  the PFkeys setting.  Full support */
/*                                  added for Mixed case nicknames,   */
/*                                  indirect message routing, string  */
/*                                  settings, and normal time display */
/*                                  rather than 24 hour time.  New    */
/*                                  settings: BEEP,BEEPCHAR,BEEPDELAY */
/*                                  HIGH,LOW,IGNMSG,NOTIFY,MPREFIX and*/
/*                                  NOWRAP, the last three replacing  */
/*                                  the old MESSAGE, PREFIX and NOWRAP*/
/*                                  commands of XYZZY Release 2.2     */
/*                                                                    */
/*       2.4   -   March 3, 1987  - Several bug fixes - NAMEZON code  */
/*                                  rewritten.. mods to MACRO, FILES  */
/*                                  and internal HELP. Several new    */
/*                                  settings. DCL command and IBMMODE */
/*                                  setting for XYZZY-VAX compat. Two */
/*                                  major new features: external cmd  */
/*                                  hooks and input expansion.        */
/*                                                                    */
/*       2.5   -   March 5, 1987  - Clean up version of 2.4. No major */
/*                                  changes except fixing up NAMEZON  */
/*                                  command and some doc changes.     */
/*                                                                    */
/*--------------------------------------------------------------------*/

