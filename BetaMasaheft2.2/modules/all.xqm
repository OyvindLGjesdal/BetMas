xquery version "3.1" encoding "UTF-8";
module namespace all = "https://www.betamasaheft.uni-hamburg.de/BetMas/all";
import module namespace console = "http://exist-db.org/xquery/console";

declare function all:subs($query, $homophones, $mode) {
    let $all :=
    for $b in $homophones
    return
    for $q in $query return
        if (contains($q, $b)) then
            let $options := 
                    for $s in $homophones[. != $b]
                            return
                                (
                                replace($q, $b, $s),
                                if ($mode = 'ws') then
                                    (replace($q, $b, ''))
                                     else()
                                )
             let $checkedoptions := 
                      for $o in $options 
                           return
                          if ($o = $query) then () else $o
            return
                $checkedoptions
        else
            ()
   let $queryAndAll := ($query, $all)
   return distinct-values($queryAndAll)
};


declare function all:substitutionsInQuery($query as xs:string*) {
    let $query-string := normalize-space($query)
    let $emphaticS := ('s','s', 'ḍ')
    let $query-string := all:subs($query-string, $emphaticS, 'normal')
 let $a := ('a','ä')
    let $query-string := all:subs($query-string, $a, 'normal')
        
    let $e := ('e','ǝ','ə','ē')
    let $query-string := all:subs($query-string, $e, 'normal')
    
     let $Ww:= ('w','ʷ')
    let $query-string := all:subs($query-string, $Ww, 'normal')
     
    (:Remove/ignore ayn and alef:)
    let $alay := ('ʾ', 'ʿ')
    let $query-string := all:subs($query-string, $alay, 'ws')
    
    (:  substitutions of homophones:)
    let $laringals14 := ('ሀ', 'ሐ', 'ኀ', 'ሃ', 'ሓ', 'ኃ')
    let $query-string := all:subs($query-string, $laringals14, 'normal')
    
   
    let $laringals2 := ('ሀ', 'ሐ', 'ኀ')
    let $query-string := all:subs($query-string, $laringals2, 'normal')
    let $laringals3 := ('ሂ', 'ሒ', 'ኂ')
    let $query-string := all:subs($query-string, $laringals3, 'normal')
    let $laringals5 := ('ሄ', 'ሔ', 'ኄ')
    let $query-string := all:subs($query-string, $laringals5, 'normal')
    let $laringals6 := ('ህ', 'ሕ', 'ኅ')
    let $query-string := all:subs($query-string, $laringals6, 'normal')
    let $laringals7 := ('ሆ', 'ሖ', 'ኆ')
    let $query-string := all:subs($query-string, $laringals7, 'normal') 
    
    
  let $ssound := ('ሠ','ሰ')
    let $query-string :=   all:subs($query-string, $ssound, 'normal')
  let $ssound2 := ('ሡ','ሱ')
    let $query-string :=   all:subs($query-string, $ssound2, 'normal')   
  let $ssound3 := ('ሢ','ሲ')
    let $query-string :=   all:subs($query-string, $ssound3, 'normal')   
  let $ssound4 := ('ሣ','ሳ')
    let $query-string :=   all:subs($query-string, $ssound4, 'normal')   
  let $ssound5 := ('ሥ','ስ')
    let $query-string :=   all:subs($query-string, $ssound5, 'normal')    
  let $ssound6 := ('ሦ','ሶ')
    let $query-string :=   all:subs($query-string, $ssound6, 'normal')   
  let $ssound7 := ('ሤ','ሴ')
    let $query-string :=   all:subs($query-string, $ssound7, 'normal')  
   
        let $emphaticT1 := ('ጸ', 'ፀ')
    let $query-string := all:subs($query-string, $emphaticT1, 'normal')
       let $emphaticT2 := ('ጹ', 'ፁ')
    let $query-string := all:subs($query-string, $emphaticT2, 'normal')
        let $emphaticT3 := ('ጺ', 'ፂ')
    let $query-string := all:subs($query-string, $emphaticT3, 'normal')
        let $emphaticT4 := ('ጻ', 'ፃ')
    let $query-string := all:subs($query-string, $emphaticT4, 'normal')
        let $emphaticT5 := ('ጼ', 'ፄ')
    let $query-string := all:subs($query-string, $emphaticT5, 'normal')
        let $emphaticT6 := ('ጽ', 'ፅ')
    let $query-string := all:subs($query-string, $emphaticT6, 'normal')
        let $emphaticT7 := ('ጾ', 'ፆ')
    let $query-string := all:subs($query-string, $emphaticT7, 'normal')
    
      let $asounds14 :=   ('አ', 'ዐ', 'ኣ', 'ዓ')
    let $query-string := all:subs($query-string, $asounds14, 'normal')
    
    let $asounds2 := ('ኡ', 'ዑ')
    let $query-string := all:subs($query-string, $asounds2, 'normal')
    let $asounds3 := ('ኢ', 'ዒ')
    let $query-string := all:subs($query-string, $asounds3, 'normal')
    let $asounds5 := ('ኤ', 'ዔ')
    let $query-string := all:subs($query-string, $asounds5, 'normal')
    let $asounds6 := ('እ', 'ዕ')
    let $query-string := all:subs($query-string, $asounds6, 'normal')
    let $asounds7 := ('ኦ', 'ዖ')
    let $query-string := all:subs($query-string, $asounds7, 'normal') 
  
  (:let $query-string := 
  let $QUERY := 
  for $word in $query-string return if(matches($word, '^[aeiouAEIOU]')) then $word|| ' ʾ' || $word || ' ʿ' || $word else $word return $QUERY
:)
    
    return
        string-join($query-string, ' ')

};