xquery version "3.0" encoding "UTF-8";

module namespace item="https://www.betamasaheft.uni-hamburg.de/BetMas/item";
import module namespace config="https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "config.xqm";
import module namespace apprest = "https://www.betamasaheft.uni-hamburg.de/BetMas/apprest" at "apprest.xqm";
import module namespace titles="https://www.betamasaheft.uni-hamburg.de/BetMas/titles" at "titles.xqm";
import module namespace app="https://www.betamasaheft.uni-hamburg.de/BetMas/app" at "app.xqm";
import module namespace console="http://exist-db.org/xquery/console";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace s = "http://www.w3.org/2005/xpath-functions";
declare namespace t="http://www.tei-c.org/ns/1.0";

(:used by item:restNav:)
declare function item:witnesses($id){
let $item := collection($config:data-rootW, $config:data-rootMS)//t:TEI/id($id)
return
if($item/@type='mss') then <div class="col-md-2"><div class="container-fluid well" id="textWitnesses">
<h5>Transcription of the manuscript</h5></div></div>
else
<div class="col-md-2" id="textWitnesses">
<div class="container-fluid well">
<h5>Witnesses of the edition</h5>
<ul class="nodot">{for $wit in $item//t:witness return 
<li class="nodot" id="{string($wit/@xml:id)}"><a href="/manuscripts/{string($wit/@corresp)}/main" target="_blank"><b class="lead">{string($wit/@xml:id)}</b>: {titles:printTitleID(string($wit/@corresp))}</a></li>}</ul>
       {let $versions := collection($config:data-root)//t:relation[@name='saws:isVersionOf'][contains(@passive, $id)]
       return
       if($versions) then (<h5>Other versions</h5>,
         <ul  class="nodot">
                {
                    for $parallel in $versions
                    let $p := $parallel/@active
                    return
                        <li><a
                                href="{$p}" class="MainTitle"  data-value="{$p}" >{$p}</a></li>
                }
            </ul>)
            else()}
            {let $versionsO := collection($config:data-root)//t:relation[@name='isVersionInAnotherLanguageOf'][contains(@passive, $id)]
       return
       if($versionsO) then (
            <h5>Versions in another language</h5>,
            <ul  class="nodot">
                {
                    for $parallel in $versionsO
                     let $p := $parallel/@active
                    return
                        <li><a
                                href="{$p}" class="MainTitle"  data-value="{$p}" >{$p}</a></li>
                }
            </ul>)
            else()}

            <a role="button" class="btn btn-primary" href="/compare?workid={$id}" target="_blank">Compare</a>
</div>
</div>
};


declare function item:RestViewOptions($this, $collection) {
let $document := $this
let $id := string($this/@xml:id)
return
<div xmlns="http://www.w3.org/1999/xhtml" class="row-fluid full-width-tabs" id="options">
<ul  class="nav nav-tabs">
<li class="span_full_width"><a href="/{$collection}/{$id}/main" target="_blank" >Entry</a></li>
<li class="span_full_width"><a href="{( '/tei/' || $id ||  '.xml')}" target="_blank">TEI/XML</a></li>
    {if(($collection = 'institutions' or $collection = 'places') and ($document//t:geo/text() or $document//t:place[@sameAs] )) then 
    <li class="span_full_width"><a href="/{( $id || 
    '.json')}" target="_blank">geoJson</a></li> else ()}
<li class="span_full_width"><a href="/{$collection}/{$id}/analytic" target="_blank">Relations</a></li>
    {if ($collection = 'manuscripts' or $collection = 'works' or $collection = 'narratives') then 
    <li class="span_full_width"><a href="{('/'||$collection|| '/' || $id || '/text' )}" target="_blank">Text</a></li> else ()}
    {if ($collection = 'manuscripts' and $this//t:msIdentifier/t:idno/@facs) then 
    <li class="span_full_width"><a href="{('/manuscripts/' || $id || '/viewer' )}" target="_blank">Images</a></li> else ()}
    {if ($collection = 'manuscripts' and $this//t:facsimile/t:graphic) then 
    <li class="span_full_width"><a href="{$this//t:facsimile/t:graphic/@url}" target="_blank">Link to images</a></li> else ()}
    {if ($collection = 'works' or $collection = 'narratives') then
    <li class="span_full_width"><a href="{('/compare?workid=' || $id  )}" target="_blank">Compare</a></li> else ()}
    </ul>
    </div>
};

(:produces each item header with contents:)

declare function item:RestItemHeader($this, $collection) {
let $document := $this
let $id := string($this/@xml:id)
let $repoID := if ($document//t:repository/text() = 'Lost') then ($document//t:repository/text()) else if ($document//t:repository/@ref) then $document//t:repository/@ref else 'No Repository Specified'
let $repo := collection($config:data-rootIn)//id($repoID)
let $repoplace := if ($repo//t:settlement[1]/@ref) then titles:printTitleID($repo//t:settlement[1]/@ref) else if ($repo//t:country[1]/@ref) then titles:printTitleID($repo//t:country[1]/@ref) else ()
let $reponame := titles:printTitleID($repoID)
let $key := $document//t:titleStmt/t:editor[not(@role = 'generalEditor')]/@key  
        
return

    <div xmlns="http://www.w3.org/1999/xhtml" class="ItemHeader col-md-12">
            
    <div xmlns="http://www.w3.org/1999/xhtml" class="col-md-8">
            <h1 id="headtitle">
                {titles:printTitleID($id)}
            </h1>
          <p id="mainEditor"><i>Edited by  {app:editorKey(string($key))}</i></p>
          </div>
                    
                 
    <div xmlns="http://www.w3.org/1999/xhtml" class="col-md-4">
                  

    <div class="row-fluid" id="general">
   <div>
   { if (count($document//t:change[not(@who='PL')]) eq 1) then
   <span class="label label-warning" >Stub</span>
   else if ($document//t:change[contains(.,'completed')]) then
   <span class="label label-info" >Under Review</span>
     else if ($document//t:change[contains(.,'reviewed')]) then
   <span class="label label-success" >Version of {max($document//t:change/xs:date(@when))}</span>
   else
<span class="label label-danger" >Work In Progress, Please don't use as reference</span>
    }
    </div>
 {switch ($collection)
case 'manuscripts' return
    if($document//t:repository/text() = 'Lost') 
    then <div><span class="label label-danger">Lost</span>  
    <p class="lead">Collection:  {$document//t:msIdentifier/t:collection}</p>
            
            {if($document//t:altIdentifier) then
            <p>Other identifiers: {
            let $otheridentifiers :=
                   let $otherids := for $altId in $document//t:msIdentifier/t:altIdentifier/t:idno/text()
                    return ($altId || ', ')
                   return <otherids>{$otherids}</otherids>
            return 
                replace($otheridentifiers/text(), ', $','')
            }
            </p>
            else
            ()
            }</div>
    else
let $mssSameRepo := 
            for $corr in collection($config:data-rootMS)//t:repository[ft:query(@ref, $repoID)]
             order by ft:score($corr) descending
            return 
                $corr  
return
<div>
                <span class="label label-success" 
                data-toggle="modal" data-target="#{$repoID}list">{if($repoplace) then ($repoplace, ', ') else ()}
                   {$reponame}</span>
                    <div id="{$repoID}list"  class="modal fade" role="dialog">
                        <div class="modal-dialog">
                                <div class="modal-content">
                                    <div class="modal-header">
                                            <h4 class="modal-title">Also the following {count($mssSameRepo)} Manuscripts are preserved at <a href="{$repoID}">{$reponame}</a></h4>
                                    </div>
                                    <div class="modal-body">
                                            <ul>{
                                                apprest:referencesList($id, $mssSameRepo, 'link')
                                             }
                                             </ul>
                                    </div>
                                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                              </div>
                        </div>
             </div>
      
 
 
 <p class="lead">Collection:  {$document//t:msIdentifier/t:collection}</p>
            
            {if($document//t:altIdentifier) then
            <p>Other identifiers: {
            let $otheridentifiers :=
                   let $otherids := for $altId in $document//t:msIdentifier/t:altIdentifier/t:idno/text()
                    return ($altId || ', ')
                   return <otherids>{$otherids}</otherids>
            return 
                replace($otheridentifiers/text(), ', $','')
            }
            </p>
            else
            ()
            }
            </div>
            case 'persons' return if(starts-with($document//t:person/@sameAs, 'Q')) then app:wikitable(string($document//t:person/@sameAs)) else (string($document//t:person/@sameAs))
                   
            case 'works' return
            app:clavisIds($document)
 case 'institutions' return 
                    
                            <div>
                            <a href="/institutions/" role="label" class="label label-success">Institution</a>
                            
{                            if($document//t:place/@type) 
   then 
   
    let $type := data($document//t:place/@type)
    let $list := if(contains($type, ' ')) then tokenize(normalize-space($type), ' ') else string($type)
    for $t in $list
        let $otherSameType :=
            for $corr in collection($config:data-rootPl, $config:data-rootIn)//t:place[ft:query(@type, $t)]
             order by ft:score($corr) descending
            return 
                $corr  
        return
                <div>
                <span class="label label-success" data-toggle="modal" data-target="#{$t}list">{$t}</span>
                <div id="{$t}list"  class="modal fade" role="dialog">
                        <div class="modal-dialog">
                                <div class="modal-content">
                                    <div class="modal-header">
                                            <h4 class="modal-title">There are other {count($otherSameType)}  places with type {string($t)}</h4>
                                    </div>
                                    <div class="modal-body">
                                    <ul>
                                            {
                                              apprest:referencesList($id, $otherSameType, 'link')
                                             }
                                             </ul>
                                    </div>
                                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                              </div>
                        </div>
             </div>
             </div>
                
            else ()}</div>
            
 case 'places' return 
 
   if($document//t:place/@type) 
   then 
   
    let $type := data($document//t:place/@type) 
    let $list := if(contains($type, ' ')) then tokenize(normalize-space($type), ' ') else string($type)
    for $t in $list
        let $otherSameType :=
            for $corr in collection($config:data-rootPl, $config:data-rootIn)//t:place[ft:query(@type, $t)]
             order by ft:score($corr) descending
            return 
                $corr  
        return
        <div>
                <span class="label label-success" data-toggle="modal" data-target="#{$t}list">{$t}</span>
                    <div id="{$t}list"  class="modal fade" role="dialog">
                        <div class="modal-dialog">
                                <div class="modal-content">
                                    <div class="modal-header">
                                            <h4 class="modal-title">There are other {count($otherSameType)}  places with type {string($t)}</h4>
                                    </div>
                                    <div class="modal-body">
                                            <ul>{
                                                apprest:referencesList($id, $otherSameType, 'link')
                                             }
                                             </ul>
                                    </div>
                                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                              </div>
                        </div>
             </div>
             </div>
      
                
            else ()
 
 case 'persons' return 
 if($document//t:personGrp) then
                            <span class="label label-success">
                            {if ($document//t:personGrp[@role = 'ethnic']) then 'Ethnic/Linguistic' else ()}
                            Group</span> else ()
 case 'work' return 
  if ($document//t:titleStmt/t:author) then <p class="lead"><a href="{$document//t:titleStmt/t:author[1]/@ref}">{$document//t:titleStmt/t:author[1]}</a></p> else ()
   default return ()
   }                  
                  
                
</div>
 
</div>
     
 
</div>
        
};

(:called by item:restNav, makes the boxes where the main relations are dispalied:)
declare function item:mainRels($this,$collection){
      let $document := $this
      let $id := string($this/@xml:id)
      let $w := collection($config:data-rootW)
      let $ms := collection($config:data-rootMS)
      return
          <div class="allMainRel">{
     switch($collection)
     case 'persons' return (
     let $isSubjectof := 
            for $corr in $w//t:TEI//t:relation[@passive = $id][@name = 'ecrm:P129_is_about']
             
            return 
                $corr  
return
<div class="mainrelations">
                                           
                                            <div  class="relBox alert alert-info">
                                            {
                  
                   if ($isSubjectof) then  (<b>This person is subject of the following works</b>,
                        <ul>{
                        for $p in $isSubjectof
                    return
                        if (contains($p/@active, ' ')) then for $value in tokenize ($p/@active, ' ') return 
                        <li><a href="{$value}">{titles:printTitleID(string($value))}</a></li>
                        else
                        <li><a href="{$p/@active}">{titles:printTitleID(string($p/@active))}</a></li>
                        }</ul>) else ()
                
                }
                </div>
                
             </div>
      )
       case 'places' return (
     let $isSubjectof := 
            for $corr in $w//t:TEI//t:relation[@passive = $id][@name = 'ecrm:P129_is_about']
             
            return 
                $corr  
return
<div  class="mainrelations">
                                           
                                            <div  class="relBox alert alert-info">
                                            {
                  
                     if ($isSubjectof) then (<b>This place is subject of the following works</b>,
                        <ul>{
                        for $p in $isSubjectof
                    return
                        if (contains($p/@active, ' ')) then for $value in tokenize ($p/@active, ' ') return 
                        <li><a href="{$value}" >{titles:printTitleID(string($value))}</a></li>
                        else
                        <li><a href="{$p/@active}">{titles:printTitleID(string($p/@active))}</a></li>
                        }</ul>) else ()
                
                }
                </div>
                
             </div>
      )
     case 'works' return (
     let $relatedWorks := 
            for $corr in $w//t:TEI[@xml:id [. != $id]]//t:relation[@* = $id][@name [. != 'saws:isAttributedToAuthor'][. != 'dcterms:creator']]
             
            return 
                $corr  
let $relations := $document//t:relation[@name [. != 'saws:isAttributedToAuthor'][. != 'dcterms:creator']]
return
if(empty($relatedWorks) and not($document//t:relation)) then ()
else
<div  class="mainrelations">
                                           
                                            
                                            {
                    for $par in $relations
                    let $relname := string(($par/@name)[1])
                    group by $rn := $relname 
                    return
                      <div  class="relBox alert alert-info"> {( 
                       
                       switch($rn)
                        case 'saws:contains' return <b>The following parts of this work are also independent works ({$rn})</b>
                        case 'ecrm:P129_is_about' return <b>The following subjects are treated in this work  ({$rn})</b>
                       case 'saws:isVersionInAnotherLanguageOf' return <b>The following Textual Units are versions in other languages of this ({$rn})</b>
                         case 'saws:formsPartOf' return <b>This work is included in the following works ({$rn})</b>
                        case 'saws:isDifferentTo' return <b>This work is marked as different from the current ({$rn})</b>
                       default return <b>The following works have a relation {$rn} with this work</b>,
                      
                      <ul>{for $p in $par/@passive
                        let $normp := normalize-space($p)
                        return
                        if (contains($normp, ' ')) then
                        for $value in tokenize ($normp, ' ') return 
                        <li><a href="{$value}" >{titles:printTitleID($value)}</a></li>
                        else
                        <li><a href="{$p}">{titles:printTitleID($p)}</a></li>
                        }</ul>)
                
                }</div>}
                
                {
                    for $par in $relatedWorks
                    let $relname := string(($par/@name)[1])
                    group by $rn := $relname 
                    return
                     <div  class="relBox alert alert-info"> 
                     {( switch($rn)
                        case 'saws:isVersionOf' return <b>The following Textual Units are versions of this ({$rn})</b>
                        case 'saws:isVersionInAnotherLanguageOf' return <b>The following Textual Units are versions in other languages of this ({$rn})</b>
                        case 'saws:isDifferentTo' return <b>This work is marked as different from the current ({$rn})</b>
                       default return <b>The following works have a relation {$rn} with this work</b>,
                        <ul>{for $p in $par
                        return
                        <li><a href="{$p/@active}">{titles:printTitleID(string($p/@active))}</a></li>
                        }</ul>)
                } </div>}
                
                                        
                              
             </div>
      )
 
 case 'institutions' return (
 let $mssSameRepo := 
            for $corr in $ms//t:repository[ft:query(@ref, $id)]
             order by ft:score($corr) descending
            return 
               $corr
return
(<b>Manuscripts at this institution</b>,
<div class="mainrelations">
                   <ul>{
                                            for $ms in $mssSameRepo
                                         let $rootid := root($ms)//t:TEI/@xml:id
                                        let $number := analyze-string($rootid, '(\d+)')
                                          let $numericvalue := number($number//s:group[@nr='1']/text())
                                         let $msID := string($rootid)
                                            order by $numericvalue
                                            return 
                                            <li><a href="{$msID}">{titles:printTitleID($msID)}</a></li>
                                            
                                             }
                                             </ul>
                                    
             </div>))
 
 default return ('No major relationship with any other item yet.')
     }</div>
      };
      
   
(:returns the navigation bar with links to items and is called by the RESTXQ module items.xql :)
declare function item:RestNav ($this, $collection, $type) {
let $document := $this
let $id := string($this/@xml:id)
return
 

            if($type = 'text') then  item:witnesses($id) else
            <div class="col-md-2"><nav class="navbar" id="ItemSideBar">
            <div class="navbar-header">
                <button type="button" class="navbar-toggle" data-toggle="collapse" data-target="#navbar-collapse-2">
                    <span class="sr-only">Toggle Item Navigation</span>
                    <span class="icon-large icon-plus-sign"/>
                </button>
                <a class="navbar-brand" href="/">Item Navigation</a><span/>
</div>
    <div class="navbar-collapse collapse" id="navbar-collapse-2">
       
        
    <ul class="nav nav-pills nav-stacked">
{
    transform:transform(
        $document,
        
        'xmldb:exist:///db/apps/BetMas/xslt/nav.xsl'
        ,
        ()
    )}
    </ul>
    
    
    </div> 
    </nav>
    
   {item:mainRels($this, $collection)}
</div>
           
      };   

(:used by item:RestPersRole():)
declare function item:sameRole($role as xs:string){
<span class="label label-info" role="btn btn-small" data-toggle="modal" data-target="#{$role}list">{$role}</span>,
let $selector := collection($config:data-root)//t:persName[@ref != 'PRS00000'][@role = $role]
            let $otherSameType :=
            for $corr in $selector
             order by ft:score($corr) descending
            return 
                $corr  
        return
        <div>
                    <div id="{$role}list"  class="modal fade" role="dialog">
                        <div class="modal-dialog">
                                <div class="modal-content">
                                    <div class="modal-header">
                                            <h4 class="modal-title">There are other {count($otherSameType)} {$role}s</h4>
                                    </div>
                                    <div class="modal-body">
                                            <ul>{
                                            for $scribe in distinct-values($otherSameType/@ref)
                                                return
                                               <li> {try {<a href="{$scribe}">{titles:printTitleID($scribe)}</a>}
                                                catch * {$scribe || ' (not yet in the database)'}}</li>
                                             }
                                             </ul>
                                    </div>
                                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                              </div>
                        </div>
             </div>
             </div>
            
};  

(:called by he RESTXQ module items.xql :)
declare function item:RestPersRole($file, $collection){
    let $c := collection($config:data-root)
    let $id := string($file/@xml:id)
    return
if ($collection = 'persons') then(
<div  class="well">{
let $persrole := $c//t:persName[@ref = $id][@role]
return
if($persrole) then
for $role in $persrole
             group by $r := $role/@role
            return 
             <div>{<span class="MainTitle" data-value="{$id}"></span>} is {item:sameRole($r)}  of 
             <ul class="lead">
            {for $root in $role/ancestor::t:TEI[@xml:id !=$id]
            let $thisid := string($root/@xml:id)
                   return
                   <li><a href="{$thisid}">{titles:printTitleID($thisid)}</a></li>}
                   </ul>
                   </div>
          else ('This person is mentioned nowhere with a specific role.')  }
            
</div>
           )
           
else if ($collection = 'manuscripts' or $collection = 'works' or $collection = 'narratives') then(
    let $pers := $file//t:persName[@ref != 'PRS00000'][@role]
    return 
        for $p in $pers
        
        group by $ID := $p/@ref
       
 return
<div  class="well">
    <a href="{$ID}">{titles:printTitleID($ID)}</a> 
    is <span class="label label-success" role="btn btn-small">{for $role in distinct-values($p/@role) return string($role) || ' '}</span>{' of this manuscript'}.

    {
    for $role in $c//t:TEI[@xml:id !=$id]//t:persName[@ref = string($ID)][@role]
    
    group by $r := $role/@role
            
            return 
             
        <ul>and is also {item:sameRole($r)} of :
            
                {
                for $root in $role/ancestor::t:TEI[@xml:id !=$id]
                   return
                   <li class="lead"><a href="{string($root/@xml:id)}">{titles:printTitleID(string($root/@xml:id))}</a></li>
                    
                }
                
        </ul>
    }
        
</div>
    
)

else ()
           };   
           
declare function item:RestAdditions($id){
       let $adds := collection($config:data-rootMS)//t:additions
       let $sameKey := 
            for $corr in $adds//t:persName[@ref= $id]
            return $corr 
return
   <div class="container-fluid col-md-6" id="InAdditions">
   <h4 class="modal-title">{count($sameKey)} Addition{if(count($sameKey) gt 1) then 's' else ()} name{if(count($sameKey) gt 1) then () else 's'} person <span class="MainTitle" data-value="{$id}">{$id}</span> </h4>
                       <div id="InAdditions{$id}">
                                           <ul>{
                                                apprest:referencesList($id, $sameKey, 'name')
                                             }
                                             </ul>
                                    </div>
                                    
                                </div>
       };
       
declare function item:RestTabot($id){
       let $tabot := collection($config:data-rootPl, $config:data-rootIn)//t:place//t:ab[@type='tabot']
       let $sameKey := 
            for $corr in $tabot//t:persName[@ref = $id]
            return $corr  
                
return

<div class="container-fluid col-md-6" id="tabots">
   <h4 class="modal-title">{count($sameKey)} place record{if(count($sameKey) gt 1) then 's' else ()} name{if(count($sameKey) gt 1) then () else 's'} person <span class="MainTitle" data-value="{$id}">{$id}</span> as a tabot</h4>
                                    
                       <div id="Tabot{$id}">
                                           <ul>{
                                                apprest:referencesList($id, $sameKey, 'name')
                                             }
                                             </ul>
                                    </div>
                                    
                                </div>

       };
       
declare function item:RestMss($id){
       let $string := $id
let $sameKey := 
            for $corr in collection($config:data-rootMS)//t:title[@ref = $id]
            return 
                $corr  
return

   <div class="alert alert-success">
   <h4 >This Work is contained in 
                                            Manuscript records {count($sameKey)} time{if(count($sameKey) gt 1) then 's' else ()}</h4>
                                    
    <div id="Samekeyword{$string}"  >
                                            
                                    
                                            <ul class="nodot">{
                                                for $hit in  $sameKey
                                              let $root := root($hit)/t:TEI/@xml:id
                                              let $tit := titles:printTitleID($root)
                                             
                                                group by $groupkey := $root
                                                 order by $tit[1]
                                                
                                               (: inside the list then :) 
(:                                                         order by root($hit)/t:TEI/@xml:id:)
                                                    return 
                                                    
                                                          <li class="list-group"><a 
                                               href="/manuscripts/{$groupkey}/main">{$tit} ({string($groupkey)}) </a> 
                                                         
                                                         <ul class="nodot">{
                                                         for $h in $hit
                                                         return

<li>{if (contains($h/@ref, '#')) then substring-after($h/@ref, '#') else ('in a ' || name($h) || ' element without ID')}</li>
                                                         }
                                                         </ul>
                                                         
                                                            </li>
                                             }
                                             </ul>
                                    </div>
                                    
     </div>
       };
       
 declare function item:RestSeeAlso ($this, $collection)  {
 let $file := $this
 let $id := string($this/@xml:id)
 return
       <div class="col-md-{if($collection = 'works' or $collection = 'places' or $collection = 'narratives') then '4' else '12'}" id="seeAlsoForm" >
       
    
       <p class="lead">Select one of the keywords listed from the record to see related data</p>
        <form action="" class="form">
            <div class="form-group">
                <div class="input-group">
                    <select class="form-control" name="seealso" id="seealsoSelector">
                    <option>select...</option>
                   {switch($collection)
(:                   decides on the basis of the collection what is relevant to match related records :)
                   case 'manuscripts' return 
                   (if ($file//t:term/@key) then <optgroup label="keywords">{for $x in ($file//t:term/@key) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:supportDesc/t:material/@key) then <optgroup label="material">{for $x in ($file//t:supportDesc/t:material/@key) return <option value="{$x}">{$x}</option>}</optgroup> else (),
                   if ($file//t:handNote[@script]/@script) then <optgroup label="script">{for $x in distinct-values($file//t:handNote[@script]/@script) return <option value="{$x}">{string($x)}</option>}</optgroup> else (),
                   if ($file//t:objectDesc/@form) then <optgroup label="form">{for $x in distinct-values($file//t:objectDesc/@form) return <option value="{$x}">{string($x)}</option>}</optgroup> else ())
                   case 'works' return 
                   (if ($file//t:term/@key) then <optgroup label="keywords">{for $x in ($file//t:term/@key) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:relation[@name='dcterms:creator']) then <optgroup label="author">{for $x in ($file//t:relation[@name='dcterms:creator']) let $auth := string($x/@passive) return <option value="{$auth}">{titles:printTitleID($auth)}</option>}</optgroup> else (),
                   if ($file//t:relation[@name='saws:isAttributedToAuthor']) then <optgroup label="attributed author">{for $x in ($file//t:relation[@name='saws:isAttributedToAuthor']) let $auth := string($x/@passive) return <option value="{$auth}">{titles:printTitleID($auth)}</option>}</optgroup> else ()
                   )
                    case 'narratives' return 
                   (if ($file//t:term/@key) then <optgroup label="keywords">{for $x in ($file//t:term/@key) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:relation[@name='dcterms:creator']) then <optgroup label="author">{for $x in ($file//t:relation[@name='dcterms:creator']) let $auth := string($x/@passive) return <option value="{$auth}">{titles:printTitleID($auth)}</option>}</optgroup> else (),
                   if ($file//t:relation[@name='saws:isAttributedToAuthor']) then <optgroup label="attributed author">{for $x in ($file//t:relation[@name='saws:isAttributedToAuthor']) let $auth := string($x/@active) return <option value="{$auth}">{titles:printTitleID($auth)}</option>}</optgroup> else ()
                   )
                   case 'places' return 
                   (if ($file//t:country or $file//t:region or $file//t:settlement) then <optgroup label="larger places">{for $x in ($file//t:settlement/@ref, $file//t:region/@ref, $file//t:country/@ref) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:place[@type]) then <optgroup label="type">{if(contains($file//t:place/@type, ' ')) then for $x in tokenize($file//t:place/@type, ' ')  return <option value="{$x}">{titles:printTitleID($x)}</option> else let $type := $file//t:place/@type return <option value="{$type}">{titles:printTitleID($type)}</option>}</optgroup> else ()
                   )
                   case 'institutions' return 
                   (if ($file//t:country or $file//t:region or $file//t:settlement) then <optgroup label="larger places">{for $x in ($file//t:settlement/@ref, $file//t:region/@ref, $file//t:country/@ref) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:place[@type]) then <optgroup label="type">{if(contains($file//t:place/@type, ' ')) then for $x in ($file//t:place/@type)  return <option value="{$x}">{titles:printTitleID($x)}</option> else let $type := $file//t:place/@type return <option value="{$type}">{titles:printTitleID($type)}</option>}</optgroup> else ()
                   )
                   case 'persons' return 
                   (if ($file//t:roleName) then <optgroup label="role">{for $x in ($file//t:roleName/@type) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:faith) then <optgroup label="faith">{for $x in ($file//t:faith/@type) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else (),
                   if ($file//t:occupation) then <optgroup label="occupation">{for $x in ($file//t:occupation/@type) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else ()
                   )
                  default return (if ($file//t:term/@key) then <optgroup label="keywords">{for $x in ($file//t:term/@key) return <option value="{$x}">{titles:printTitleID($x)}</option>}</optgroup> else ()
                   )}
                   </select>
                    </div>
            </div>
        </form>
     <img id="loading" src="resources/Loading.gif" style="display: none;"></img>
     <div id="SeeAlsoResults" class="well">No keyword selected.</div>
     {if($collection='works') then item:RestMss($id) else ()}
    </div>
      };
        
declare function item:RestItem($this, $collection) {
let $document := $this
let $id := string($document/t:TEI/@xml:id)
return
let $xslt :=  switch($collection)
        case "manuscripts"  return       'xmldb:exist:///db/apps/BetMas/xslt/mss.xsl' 
        case "places"  return       'xmldb:exist:///db/apps/BetMas/xslt/placeInstit.xsl' 
        case "institutions"  return       'xmldb:exist:///db/apps/BetMas/xslt/placeInstit.xsl'
        case "persons"  return       'xmldb:exist:///db/apps/BetMas/xslt/Person.xsl'
        case "works"  return       'xmldb:exist:///db/apps/BetMas/xslt/Work.xsl' 
        case "narratives"  return       'xmldb:exist:///db/apps/BetMas/xslt/Work.xsl'
        
        (:THE FOLLOWING TWO ARE TEMPORARY PLACEHOLDERS:)
        case "authority-files"  return       'xmldb:exist:///db/apps/BetMas/xslt/auth.xsl' 
        default return 'xmldb:exist:///db/apps/BetMas/xslt/Work.xsl'
        
let $parameters : = if ($collection = 'manuscripts') then <parameters>
    <param name="porterified" value="."/>
    <param name="folio" value="1"/>
    <param name="currentpos" value="1"/>
    <param name="rend" value="."/>
    <param name="from" value="."/>
    <param name="to" value="."/>
    <param name="prec" value="."/>
    <param name="count" value="."/>
    <param name="singletons" value="."/>
    <param name="step1ed" value="."/>
    <param name="step2ed" value="."/>
    <param name="step3ed" value="."/>
    <param name="Finalvisualization" value="."/>
</parameters> else ()
        
return
(:because nav takes 2 colums:)
   
    <div class="container-fluid col-md-10" > 
{transform:transform(
        $document,
       $xslt,
$parameters

    )}
    {item:RestSeeAlso($this, $collection)}
    </div>
   
    
        
};

declare  function item:RestText($this,
$start as xs:integer*, 
$per-page as xs:integer*) {
let $document := $this
let $parameters := map{}       
let $xslt :=   'xmldb:exist:///db/apps/BetMas/xslt/text.xsl'
        let $xslpars := <parameters>
    <param name="startsection" value="{$start}"/>
    <param name="perpage" value="{$per-page}"/>
</parameters>

return
if(count($document//t:div[@type='edition']) gt 1) then 
let $matches := for $hit in $document//t:div[@type='edition'][1]/t:div[@type='textpart']
                            return $hit
let $hits :=        map { 'hits' := $matches}
return
   <div class="col-md-10">
     <ul class="pagination" >
    {apprest:paginate-rest($hits, $parameters, $start, $per-page, 1, 21)}
    </ul>
                   {
    transform:transform(
        $document,
       $xslt,
$xslpars)}
    </div>
    else
if($document//t:div[@type='textpart']) then
let $matches := for $hit in $document//t:div[@type='textpart']
                            return $hit
let $hits :=        map { 'hits' := $matches}
return
   <div class="col-md-10"> 
   <a href="?per-page={count($matches)}" class="btn btn-primary">See full text</a>
    
     <ul class="pagination" >
    {apprest:paginate-rest($hits, $parameters, $start, $per-page, 1, 21)}
    </ul>
                   {
    transform:transform(
        $document,
       $xslt,
$xslpars)}
    </div>
    else if($document//t:div[@type='edition'][t:ab]) then 
    transform:transform(
        $document,
       $xslt,
$xslpars)
    else if($document//t:relation[@name="saws:contains"])
    then
    let $ids := if(contains($document//t:relation[@name="saws:contains"]/@passive, ' ')) then for $x in tokenize($document//t:relation[@name="saws:contains"]/@passive, ' ') return $x else string($document//t:relation[@name="saws:contains"]/@passive)
return
    <div class="col-md-10">
   
    { for $contained in $ids
    
    let $file := collection($config:data-rootW)//id($contained)[name()='TEI']
     let $matches := for $hit in $file//t:div[@type='textpart'] return $hit
    let $hits :=        map { 'hits' := $matches}
    
let $xsltlocalparameters  :=  <parameters>
    <param name="startsection" value="{$start}"/>
    <param name="perpage" value="{$per-page}"/>
</parameters>
    return 
     <div class="col-md-12">
     <h1><a target="_blank" href="/works/{$contained}/text">{titles:printTitleID($contained)}</a></h1>
     <ul class="pagination" >
    {apprest:paginate-rest($hits, $parameters, $start, $per-page, 1, 21)}
    </ul>
    {transform:transform(
        $file,
       $xslt,
$xslpars)}

     </div>
    }

    
    <div>
   
    </div>
    
    </div>
    else ()

    
        
};



