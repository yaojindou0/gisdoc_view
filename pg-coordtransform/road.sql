CREATE OR REPLACE FUNCTION pgr_road(
	tbl character varying,
	startx double precision,
	starty double precision,
	endx double precision,
	endy double precision,
	OUT linetype integer,
	OUT geom geometry)
    RETURNS SETOF record 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT 
    ROWS 1000
AS $BODY$  
 
  
 
declare 

 
    v_startLine geometry;--离起点最近的线 
 
    v_endLine geometry;--离终点最近的线 
 
     
 
    v_startTarget integer;--距离起点最近线的终点
 
    v_startSource integer;
 
    v_endSource integer;--距离终点最近线的起点
 
    v_endTarget integer;
 
 
 
    v_statpoint geometry;--在v_startLine上距离起点最近的点 
 
    v_endpoint geometry;--在v_endLine上距离终点最近的点 
 
     
 
    v_res geometry;--最短路径分析结果
 
    v_res_a geometry;
 
    v_res_b geometry;
 
    v_res_c geometry;
 
    v_res_d geometry; 
 
 
 
    v_perStart float;--v_statpoint在v_res上的百分比 
 
    v_perEnd float;--v_endpoint在v_res上的百分比 
 
 
 
    v_shPath_se geometry;--开始到结束
 
    v_shPath_es geometry;--结束到开始
 
    v_shPath geometry;--最终结果
 
    tempnode float;  
    
    startpoint geometry;
    endpoint geometry;
 
    v_shPath1 geometry;--一次结果
    v_shPath2 geometry;--二次结果
    star_line geometry; --起点到最近点的线
    end_line geometry; --终点到最近点的线
    geoARR geometry[];
    
    geoType integer[];
    
  
    
    ii integer;
 
begin
 

    --查询离起点最近的线 
    --4326坐标系
    --找起点15米范围内的最近线
 
    execute 'select geom, source, target  from ' ||tbl||
 
                            ' where ST_DWithin(geom,ST_Geometryfromtext(''point('||         startx ||' ' || starty||')'',4326),15000)
                             order by ST_Distance(geom,ST_GeometryFromText(''point('|| startx ||' '|| starty ||')'',4326))  limit 1'
 
                            into v_startLine, v_startSource ,v_startTarget; 
 
raise notice '%',  v_startSource;
raise notice '%', v_startTarget;
 
    --查询离终点最近的线 
    --找终点15米范围内的最近线
 
    execute 'select geom, source, target from ' ||tbl||
 
                            ' where ST_DWithin(geom,ST_Geometryfromtext(''point('|| endx || ' ' || endy ||')'',4326),15000) 
                           
                            order by ST_Distance(geom,ST_GeometryFromText(''point('|| endx ||' ' || endy ||')'',4326))  limit 1'
 
                            into v_endLine, v_endSource,v_endTarget; 
raise notice '%',  v_endSource;
raise notice '%', v_endTarget;
 
 
    --如果没找到最近的线，就返回null 
 
    if (v_startLine is null) or (v_endLine is null) then 
 
        return; 
 
    end if ; 
 
 
 
    select  ST_ClosestPoint(v_startLine, ST_Geometryfromtext('point('|| startx ||' ' || starty ||')',4326)) into v_statpoint; 
 
    select  ST_ClosestPoint(v_endLine, ST_GeometryFromText('point('|| endx ||' ' || endy ||')',4326)) into v_endpoint; 
 
   
 
   -- ST_Distance 
 
     
 
    --从开始的起点到结束的起点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startSource || ', ' ||'array['||v_endSource||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res ;
 
   
 
    --从开始的终点到结束的起点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startTarget || ', ' ||'array['||v_endSource||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_b ;
 
 
 
    --从开始的起点到结束的终点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startSource || ', ' ||'array['||v_endTarget||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_c ;
 
 
 
    --从开始的终点到结束的终点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startTarget || ', ' ||'array['||v_endTarget||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_d ;
 
 
 
    if(ST_Length(v_res) > ST_Length(v_res_b)) then
 
       v_res = v_res_b;
 
    end if;
 
   
 
    if(ST_Length(v_res) > ST_Length(v_res_c)) then
 
       v_res = v_res_c;
 
    end if;
 
   
 
    if(ST_Length(v_res) > ST_Length(v_res_d)) then
 
       v_res = v_res_d;
 
    end if;
 
             
 
 
 
    --如果找不到最短路径，就返回null 
 
    if(v_res is null) then 
 
        return; 
 
    end if; 
 
     
 
    --将v_res,v_startLine,v_endLine进行拼接 
 
    select  st_linemerge(ST_Union(array[v_res,v_startLine,v_endLine])) into v_res;
 
    --return v_res;
 
    select  ST_LineLocatePoint(v_res, v_statpoint) into v_perStart; 
 
    select  ST_LineLocatePoint(v_res, v_endpoint) into v_perEnd; 
 
        
 
    if(v_perStart > v_perEnd) then 
 
        tempnode =  v_perStart;
 
        v_perStart = v_perEnd;
 
        v_perEnd = tempnode;
 
    end if;
 
        
 
    --截取v_res 
    --拼接线
 
    SELECT ST_Line_SubString(v_res,v_perStart, v_perEnd) into v_shPath1;
 
 --接下来进行
 --找线的端点

   select ST_SetSRID( ST_MakePoint(startx , starty),4326 )into startpoint;
 select ST_SetSRID( ST_MakePoint(endx , endy),4326 )into endpoint;
 select ST_MakeLine( v_statpoint,startpoint) into star_line; 
 select ST_MakeLine( v_endpoint,endpoint) into end_line; 

 

geoARR :=array[end_line,v_shPath1,star_line];
geoType :=array[1,2,1];

    FOR ii IN 1..3 Loop 
 
    lineType:=geoType[ii];
    geom:=geoARR[ii];
    raise notice '%', '返回数据';
    return next;
    end loop;
 return;
 
end; 
 
$BODY$;

ALTER FUNCTION pgr_road(character varying, double precision, double precision, double precision, double precision)
    OWNER TO postgres;

CREATE FUNCTION "postgres"."pgr_fromctod"("tbl" varchar, "startx" float8, "starty" float8, "endx" float8, "endy" float8)
  RETURNS "public"."geometry" AS $BODY$  
 
declare 
 
    v_startLine geometry;--离起点最近的线 
 
    v_endLine geometry;--离终点最近的线 
 
     
 
    v_startTarget integer;--距离起点最近线的终点
 
    v_startSource integer;
 
    v_endSource integer;--距离终点最近线的起点
 
    v_endTarget integer;
 
 
 
    v_statpoint geometry;--在v_startLine上距离起点最近的点 
 
    v_endpoint geometry;--在v_endLine上距离终点最近的点 
 
     
 
    v_res geometry;--最短路径分析结果
 
    v_res_a geometry;
 
    v_res_b geometry;
 
    v_res_c geometry;
 
    v_res_d geometry; 
 
 
 
    v_perStart float;--v_statpoint在v_res上的百分比 
 
    v_perEnd float;--v_endpoint在v_res上的百分比 
 
 
 
    v_shPath_se geometry;--开始到结束
 
    v_shPath_es geometry;--结束到开始
 
    v_shPath geometry;--最终结果
 
    tempnode float;      
 
begin
 
    --查询离起点最近的线 
    --4326坐标系
    --找起点15米范围内的最近线
 
    execute 'select geom, source, target  from ' ||tbl||
 
                            ' where ST_DWithin(geom,ST_Geometryfromtext(''point('||startx ||' ' || starty||')'',4326),15)
                            order by ST_Distance(geom,ST_GeometryFromText(''point('|| startx ||' '|| starty ||')'',4326))  limit 1'
 
                            into v_startLine, v_startSource ,v_startTarget; 
 
     
 
    --查询离终点最近的线 
    --找终点15米范围内的最近线
 
    execute 'select geom, source, target from ' ||tbl||
 
                            ' where ST_DWithin(geom,ST_Geometryfromtext(''point('|| endx || ' ' || endy ||')'',4326),15)
                            order by ST_Distance(geom,ST_GeometryFromText(''point('|| endx ||' ' || endy ||')'',4326))  limit 1'
 
                            into v_endLine, v_endSource,v_endTarget; 
 
 
 
    --如果没找到最近的线，就返回null 
 
    if (v_startLine is null) or (v_endLine is null) then 
 
        return null; 
 
    end if ; 
 
 
 
    select  ST_ClosestPoint(v_startLine, ST_Geometryfromtext('point('|| startx ||' ' || starty ||')',4326)) into v_statpoint; 
 
    select  ST_ClosestPoint(v_endLine, ST_GeometryFromText('point('|| endx ||' ' || endy ||')',4326)) into v_endpoint; 
 
   
 
   -- ST_Distance 
 
     
 
    --从开始的起点到结束的起点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startSource|| ', ' ||'array['||v_endSource||'] , false, false 
    ) a, ' 
 
    ||tbl|| ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res ;
 
   
 
    --从开始的终点到结束的起点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startTarget|| ', ' ||'array['||v_endSource||'] , false, false 
    ) a, ' 
 
    ||tbl|| ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_b ;
 
 
 
    --从开始的起点到结束的终点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startSource || ', ' ||'array['||v_endTarget||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_c ;
 
 
 
    --从开始的终点到结束的终点最短路径
 
    execute 'SELECT st_linemerge(st_union(b.geom)) ' ||
 
    'FROM pgr_kdijkstraPath( 
    ''SELECT gid as id, source, target, length as cost FROM ' || tbl ||''',' 
 
    ||v_startTarget || ', ' ||'array['||v_endTarget||'] , false, false 
    ) a, ' 
 
    || tbl || ' b 
    WHERE a.id3=b.gid   
    GROUP by id1   
    ORDER by id1' into v_res_d ;
 
 
 
    if(ST_Length(v_res) > ST_Length(v_res_b)) then
 
       v_res = v_res_b;
 
    end if;
 
   
 
    if(ST_Length(v_res) > ST_Length(v_res_c)) then
 
       v_res = v_res_c;
 
    end if;
 
   
 
    if(ST_Length(v_res) > ST_Length(v_res_d)) then
 
       v_res = v_res_d;
 
    end if;
 
             
 
 
 
    --如果找不到最短路径，就返回null 
 
    --if(v_res is null) then 
 
    --    return null; 
 
    --end if; 
 
     
 
    --将v_res,v_startLine,v_endLine进行拼接 
 
    select  st_linemerge(ST_Union(array[v_res,v_startLine,v_endLine])) into v_res;
 
 
 
    select  ST_Line_Locate_Point(v_res, v_statpoint) into v_perStart; 
 
    select  ST_Line_Locate_Point(v_res, v_endpoint) into v_perEnd; 
 
        
 
    if(v_perStart > v_perEnd) then 
 
        tempnode =  v_perStart;
 
        v_perStart = v_perEnd;
 
        v_perEnd = tempnode;
 
    end if;
 
        
 
    --截取v_res 
    --拼接线
 
    SELECT ST_Line_SubString(v_res,v_perStart, v_perEnd) into v_shPath;
 
 
 
    return v_shPath; 
 
 
 
end; 
 
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT  COST 100
;

ALTER FUNCTION "postgres"."pgr_fromctod"("tbl" varchar, "startx" float8, "starty" float8, "endx" float8, "endy" float8) OWNER TO "postgres";

CREATE FUNCTION "postgres"."NewProc"(IN "tbl" varchar, IN "x1" float8, IN "y1" float8, IN "x2" float8, IN "y2" float8, OUT "seq" int4, OUT "gid" int4, OUT "name" text, OUT "heading" float8, OUT "cost" float8, OUT "geom" "public"."geometry")
  RETURNS SETOF "pg_catalog"."record" AS $BODY$
DECLARE
        sql     text;
        rec     record;
        source    integer;
        target    integer;
        point    integer;
        
BEGIN
    -- 查询距离出发点最近的道路节点
    EXECUTE 'SELECT id::integer FROM '|| quote_ident(tbl) ||'_vertices_pgr 
            ORDER BY the_geom <-> ST_GeometryFromText(''POINT(' 
            || x1 || ' ' || y1 || ')'',4326) LIMIT 1' INTO rec;
    source := rec.id;
    
    -- 查询距离目的地最近的道路节点
    EXECUTE 'SELECT id::integer FROM '|| quote_ident(tbl) ||'_vertices_pgr 
            ORDER BY the_geom <-> ST_GeometryFromText(''POINT(' 
            || x2 || ' ' || y2 || ')'',4326) LIMIT 1' INTO rec;
    target := rec.id;

    -- 最短路径查询 
        seq := 0;
        sql := 'SELECT gid, geom, name, cost, source, target, 
                ST_Reverse(geom) AS flip_geom FROM ' ||
                        'pgr_bdAstar(''SELECT gid as id, source::int, target::int, '
                                        || 'length::float AS cost,x1,y1,x2,y2 FROM '
                                        || quote_ident(tbl) || ''', '
                                        || source || ', ' || target 
                                        || ' ,false, false), '
                                || quote_ident(tbl) || ' WHERE id2 = gid ORDER BY seq';


    -- Remember start point
        point := source;

        FOR rec IN EXECUTE sql
        LOOP
        -- Flip geometry (if required)
        IF ( point != rec.source ) THEN
            rec.geom := rec.flip_geom;
            point := rec.source;
        ELSE
            point := rec.target;
        END IF;

        -- Calculate heading (simplified)
        EXECUTE 'SELECT degrees( ST_Azimuth( 
                ST_StartPoint(''' || rec.geom::text || '''),
                ST_EndPoint(''' || rec.geom::text || ''') ) )' 
            INTO heading;

        -- Return record
                seq     := seq + 1;
                gid     := rec.gid;
                name    := rec.name;
                cost    := rec.cost;
                geom    := rec.geom;
                RETURN NEXT;
        END LOOP;
        RETURN;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT  COST 100
 ROWS 1000
;

ALTER FUNCTION "postgres"."NewProc"(IN "tbl" varchar, IN "x1" float8, IN "y1" float8, IN "x2" float8, IN "y2" float8, OUT "seq" int4, OUT "gid" int4, OUT "name" text, OUT "heading" float8, OUT "cost" float8, OUT "geom" "public"."geometry") OWNER TO "postgres";

