xquery version "3.1" encoding "UTF-8";
(:~
 : module with function called to show content of the archival work of Gnisci at the Vatican Library in BM
 : called by gnisci.js
 : @author Pietro Liuzzo <pietro.liuzzo@uni-hamburg.de'>
 :)
module namespace chojnacki = "https://www.betamasaheft.uni-hamburg.de/BetMas/chojnacki";
import module namespace rest = "http://exquery.org/ns/restxq";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

(: For REST annotations :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";

    (:~ given an institution or place id checks the marc records from Vatican Library for relevant related data :) 
declare
%rest:GET
%rest:path("/BetMas/api/Chojnacki/{$id}")
%output:method("json")
function chojnacki:allChojnacki($id  as xs:string*){
let $Chojnacki := collection('/db/apps/BetMas/data/Chojnacki')//marc:record[descendant::marc:subfield[@code="a"][. = $id ]]
let $ChojnackItems := for $Choj in $Chojnacki
                                            let $DigiVatID := $Choj//marc:datafield[@tag="095"]/marc:subfield[@code="a"]/text()
                                            let $link := 'https://digi.vatlib.it/stp/detail/' || $DigiVatID
                                            let $name := string-join($Choj//marc:datafield[@tag="534"]/marc:subfield/text(), ' ')
                                       
                                       return
  map {'name' := $name, 'link' := $link}
return if (count($ChojnackItems) ge 1) then map {'total' := count($ChojnackItems), 'ChojnackItems' := $ChojnackItems}
else if (count($ChojnackItems) eq 1) then map {'total' := 1, 'ChojnackItems' := [$ChojnackItems]}
else map {'total' := 0, 'info' := 'sorry, there are no related items in the Chojnacki Collection at the Vatic Library.'}};
