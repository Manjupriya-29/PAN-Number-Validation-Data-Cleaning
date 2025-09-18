--- PAN Number Validation Project Using SQL ---

create table stg_pan_number_dataset
(
   pan_number    text
);

select * from stg_pan_number_dataset;

-- Identify and handle missing data:
select * from stg_pan_number_dataset where pan_number is null;

-- Check for Duplicates:
select pan_number, count(1)
from stg_pan_number_dataset
group by pan_number
having count(1) > 1;

-- Handle leading/trailing spaces:
select * from stg_pan_number_dataset where pan_number <> trim(pan_number)

-- Correct letter case:
select * from stg_pan_number_dataset where pan_number <> upper(pan_number);

-- Cleaned Pan numbers:
select distinct upper(trim(pan_number))
from stg_pan_number_dataset 
where pan_number is not null
and trim(pan_number) <> '';

-- Function to check if adjacent characters are the same --
create or replace function fn_check_adjacent_chars(p_str text)
returns boolean
language plpgsql
as $$
begin
      for i in 1 .. (length(p_str) - 1)
	  loop
	     if substring(p_str, i, 1) = substring(p_str, i+1, 1)
		 then
		   return true; -- characters are adjacent
		 end if;
	  end loop;
	  return false; -- non of the characters adjacent to each other were same
end;
$$

select fn_check_adjacent_chars('ZZOVO')


-- Function to check if sequencial characters are used
create or replace function fn_check_sequencial_chars(p_str text)
returns boolean
language plpgsql
as $$
begin
      for i in 1 .. (length(p_str) - 1)
	  loop
	     if ascii(substring(p_str, i+1, 1)) - ascii(substring(p_str, i, 1)) <> 1
		 then
		   return false; -- characters are not in sequence 
		 end if;
	  end loop;
	  return true; -- characters are in sequence
end;
$$

select ascii('X')

select fn_check_sequencial_chars('ABCDE')

-- Regular expression to validate the pattern or structure of PAN Numbers
select *  
from stg_pan_number_dataset
where pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'

-- Valid and Invalid PAN categorization
create or replace view vw_valid_invalid_pans
as
with cte_cleaned_pan as
 (select distinct upper(trim(pan_number)) as pan_number
  from stg_pan_number_dataset 
  where pan_number is not null
  and trim(pan_number) <> ''),
 cte_valid_pans as
  (select *
  from cte_cleaned_pan
  where fn_check_adjacent_chars(pan_number) = false
  and fn_check_sequencial_chars(substring(pan_number,1,5)) = false
  and fn_check_sequencial_chars(substring(pan_number,6,4)) = false
  and pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$')
select cln.pan_number
,  case when vld.pan_number is not null
            then 'Valid PAN'
		else 'Invalid PAN'
       end as status
from cte_cleaned_pan cln 
left join cte_valid_pans vld on vld.pan_number = cln.pan_number;

select * from vw_valid_invalid_pans;

-- Summary report

with cte as
  (select 
    (select count(*) from stg_pan_number_dataset) as total_processed_records,
    count(*) filter(where status = 'Valid PAN') as total_valid_pans,
    count(*) filter(where status = 'Invalid PAN') as total_invalid_pans
  from vw_valid_invalid_pans)
select total_processed_records, total_valid_pans, total_invalid_pans, 
(total_processed_records - (total_valid_pans+total_invalid_pans)) as total_missing_pans
from cte;











