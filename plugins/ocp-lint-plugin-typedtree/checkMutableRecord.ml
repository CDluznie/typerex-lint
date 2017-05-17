module Linter = Plugin_typedtree.Plugin.MakeLint(struct
    let name = "Check Use Of Mutable Field In Record"
    let version = "1"
    let short_name = "check_mutable_record"
    let details = "details" 
    let enable = true
  end)

type warning =
  | RecordMutableField
    
let w_mutable_record = Linter.new_warning
    ~id:1
    ~short_name:"mutable record"
    ~msg:"mutable record."
    ~severity:1
    
module Warnings = Linter.MakeWarnings(struct
    type t = warning

    let to_warning = function
      | RecordMutableField ->
	 w_mutable_record, []
			    
end)

let iter =
  let module IterArg = struct
    include Typedtree_iter.DefaultIteratorArgument

    let enter_structure_item str =
      let open Typedtree in
      let open Asttypes in
      match str.str_desc with
      | Tstr_type (_,tps) ->
	 List.iter begin fun tp ->
	    match tp.typ_kind with 
	    | Ttype_record lds ->
	       List.iter begin fun ld ->
	         if ld.ld_mutable = Mutable then
		   Warnings.report ld.ld_loc (RecordMutableField);
	       end lds
	    | _ -> ()
	 end tps
      | _ -> ()
  end in
  (module IterArg : Typedtree_iter.IteratorArgument)
    
module MainML = Linter.MakeInputCMT(struct
    let main cmt = Typedtree_iter.iter_structure iter cmt
  end)
