delimiter ;;
create database if not exists fastbit;;
use fastbit;;
drop procedure if exists fb_throw;;
drop procedure if exists fb_helper;;

create procedure fb_throw(v_err text) 
begin
  signal sqlstate '45000' set
    class_origin     = 'Fastbit_UDF',
    subclass_origin  = 'Fastbit_UDF',
    mysql_errno      = 45000,
    message_text     = v_err;
end;;

create procedure fb_helper(v_index varchar(1024), v_schema varchar(64), v_table varchar(64), v_query text, v_return boolean, v_drop boolean)
begin
  -- where does it go?
  set @table := CONCAT('`',v_schema,'`.`',v_table,'`');

  -- create a temporary name for the resultset on disk (intermediary file)
  set @file := concat(@@tmpdir, '/', md5(rand()), '.fcsv');

  -- run the FastBit_UDF query
  set @err := fb_query(v_index, @file, v_query);

  -- was there an error running the query?
  if not @err like 'QUERY_OK%' then
    call fb_throw(err);
  else

    -- extract metadata from the result of fb_query
    set @pos := instr(@err, '(');
    set @metadata := substr(@err, @pos, length(@err)-@pos+1); 

    -- Create the table from the metadata
    set @v_sql := CONCAT('create temporary table ',@table,@metadata);
    prepare stmt from @v_sql;
    execute stmt;
    deallocate prepare stmt;
  
    -- get resultset as insert statements 
    set @v_sql := fb_file_get_contents(@file, @table); 
    if @v_sql is null then
      call fb_throw("Could not get contents of intermediary file");
    end if;
    prepare stmt from @v_sql;
    execute stmt;
    deallocate prepare stmt;

    -- intermediary file is no longer needed
    set @err := fb_unlink(@file); 
    if @err != 0 then
      call fb_throw(concat('Error unlinking file: ', @err));
    end if;

    -- send results to client if desired
    if v_return then 
      set @v_sql := concat('select * from ',@table);
      prepare stmt from @v_sql;
      execute stmt;
      deallocate prepare stmt;
    end if;

    -- drop the table if desired	
    if v_drop then
      set @v_sql := concat('drop temporary table ', @table);
      prepare stmt from @v_sql;
      execute stmt;
      deallocate prepare stmt;
    end if;

  end if;

end;;
  
delimiter ;
