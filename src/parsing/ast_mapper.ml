(* See copyright in ast_mapper.mli *)
open Parsetree
open Ast_helper

type mapper = {
  constant: mapper -> constant -> constant;
  expr: mapper -> expression -> expression;
  pat: mapper -> pattern -> pattern;
  typ: mapper -> parsed_type -> parsed_type;
  data: mapper -> data_declaration -> data_declaration;
  constructor: mapper -> constructor_declaration -> constructor_declaration;
  location: mapper -> Location.t -> Location.t;
  import: mapper -> import_declaration -> import_declaration;
  export: mapper -> export_declaration list -> export_declaration list;
  export_data: mapper -> export_data_declaration list -> export_data_declaration list;
  export_all: mapper -> export_except list -> export_except list;
  export_data_all: mapper -> export_data_except list -> export_data_except list;
  value_binding: mapper -> value_binding -> value_binding;
  match_branch: mapper -> match_branch -> match_branch;
  value_description: mapper -> value_description -> value_description;
  toplevel: mapper -> toplevel_stmt -> toplevel_stmt;
}

let map_loc sub {loc; txt} = {loc = sub.location sub loc; txt}

module Cnst = struct
  let map sub c = c
end

module E = struct
  let map sub {pexp_desc = desc; pexp_loc = loc} =
    let open Exp in
    let loc = sub.location sub loc in
    match desc with
    | PExpId(i) -> ident ~loc (map_loc sub i)
    | PExpConstant(c) -> constant ~loc (sub.constant sub c)
    | PExpTuple(es) -> tuple ~loc (List.map (sub.expr sub) es)
    | PExpLet(r, vbs, e) -> let_ ~loc r (List.map (sub.value_binding sub) vbs) (sub.expr sub e)
    | PExpMatch(e, mbs) -> match_ ~loc (sub.expr sub e) (List.map (sub.match_branch sub) mbs)
    | PExpPrim1(p1, e) -> prim1 ~loc p1 (sub.expr sub e)
    | PExpPrim2(p2, e1, e2) -> prim2 ~loc p2 (sub.expr sub e1) (sub.expr sub e2)
    | PExpAssign(be, e) -> assign ~loc (sub.expr sub be) (sub.expr sub e)
    | PExpIf(c, t, f) -> if_ ~loc (sub.expr sub c) (sub.expr sub t) (sub.expr sub f)
    | PExpWhile(c, e) -> while_ ~loc (sub.expr sub c) (sub.expr sub e)
    | PExpLambda(pl, e) -> lambda ~loc (List.map (sub.pat sub) pl) (sub.expr sub e)
    | PExpApp(e, el) -> apply ~loc (sub.expr sub e) (List.map (sub.expr sub) el)
    | PExpBlock(el) -> block ~loc (List.map (sub.expr sub) el)
    | PExpNull -> null ~loc ()
end

module P = struct
  let map sub {ppat_desc = desc; ppat_loc = loc} =
    let open Pat in
    let loc = sub.location sub loc in
    match desc with
    | PPatAny -> any ~loc ()
    | PPatVar sl -> var ~loc (map_loc sub sl)
    | PPatTuple pl -> tuple ~loc (List.map (sub.pat sub) pl)
    | PPatConstant c -> constant ~loc (sub.constant sub c)
    | PPatConstraint(p, pt) -> constraint_ ~loc (sub.pat sub p) (sub.typ sub pt)
    | PPatConstruct(id, pl) -> construct ~loc (map_loc sub id) (List.map (sub.pat sub) pl)
    | PPatOr(p1, p2) -> or_ ~loc (sub.pat sub p1) (sub.pat sub p2)
    | PPatAlias(p, id) -> alias ~loc (sub.pat sub p) (map_loc sub id)
end

module C = struct
  let map sub {pcd_name = name; pcd_args = args; pcd_loc = loc} =
    let open CDecl in
    let loc = sub.location sub loc in
    let sname = map_loc sub name in
    match args with
    | PConstrTuple(ptl) -> tuple ~loc sname (List.map (sub.typ sub) ptl)
    | PConstrSingleton -> singleton ~loc sname
end

module D = struct
  let map sub{pdata_name = name; pdata_params = args; pdata_kind = kind; pdata_loc = loc} =
    let open Dat in
    let loc = sub.location sub loc in
    let sname = map_loc sub name in
    let sargs = List.map (sub.typ sub) args in
    match kind with
    | PDataVariant cdl -> variant ~loc sname sargs (List.map (sub.constructor sub) cdl)
end

module T = struct
  let map sub {ptyp_desc = desc; ptyp_loc = loc} =
    let open Typ in
    let loc = sub.location sub loc in
    match desc with
    | PTyAny -> any ~loc ()
    | PTyVar v -> var ~loc v
    | PTyArrow(args, ret) -> arrow ~loc (List.map (sub.typ sub) args) (sub.typ sub ret)
    | PTyTuple ts -> tuple ~loc (List.map (sub.typ sub) ts)
    | PTyConstr(name, ts) -> constr ~loc (map_loc sub name) (List.map (sub.typ sub) ts)
    | PTyPoly(vars, t) -> poly ~loc (List.map (map_loc sub) vars) (sub.typ sub t)
end

module V = struct
  let map sub {pvb_pat = pat; pvb_expr = expr; pvb_loc = loc} =
    {
      pvb_pat = sub.pat sub pat;
      pvb_expr = sub.expr sub expr;
      pvb_loc = sub.location sub loc;
    }
end

module MB = struct
  let map sub {pmb_pat = pat; pmb_body = expr; pmb_loc = loc} =
    {
      pmb_pat = sub.pat sub pat;
      pmb_body = sub.expr sub expr;
      pmb_loc = sub.location sub loc;
    }
end

module I = struct
  let map sub {pimp_mod = imod; pimp_loc = loc} =
    let open Imp in
    let loc = sub.location sub loc in
    mk ~loc (map_loc sub imod)
end

module EX = struct
  let map sub exports =
    List.map (fun {pex_name; pex_alias; pex_loc} ->
      let pex_name = map_loc sub pex_name in
      let pex_alias = match pex_alias with
        | Some(alias) -> Some(map_loc sub alias)
        | None -> None in
      let pex_loc = sub.location sub pex_loc in
      {pex_name; pex_alias; pex_loc}
    ) exports
  let map_export_all sub excepts =
    List.map (map_loc sub) excepts
end

module EXD = struct
  let map sub exports =
    List.map (fun {pexd_name; pexd_loc} ->
      let pexd_name = map_loc sub pexd_name in
      let pexd_loc = sub.location sub pexd_loc in
      {pexd_name; pexd_loc}
    ) exports
  let map_export_data_all sub excepts =
    List.map (map_loc sub) excepts
end

module VD = struct
  let map sub ({pval_mod = vmod; pval_name = vname; pval_loc = loc} as d) =
    let pval_loc = sub.location sub loc in
    let pval_mod = map_loc sub vmod in
    let pval_name = map_loc sub vname in
    {d with pval_name; pval_mod; pval_loc}
end

module TL = struct
  let map sub {ptop_desc = desc; ptop_loc = loc} =
    let open Top in
    let loc = sub.location sub loc in
    match desc with
      | PTopImport id -> Top.import ~loc (sub.import sub id)
      | PTopForeign(e, d) -> Top.foreign ~loc e (sub.value_description sub d)
      | PTopData(e, dd) -> Top.data ~loc e (sub.data sub dd)
      | PTopLet(e, r, vb) -> Top.let_ ~loc e r (List.map (sub.value_binding sub) vb)
      | PTopExport ex -> Top.export ~loc (sub.export sub ex)
      | PTopExportData ex -> Top.export_data ~loc (sub.export_data sub ex)
      | PTopExportAll ex -> Top.export_all ~loc (sub.export_all sub ex)
      | PTopExportDataAll ex -> Top.export_data_all ~loc (sub.export_data_all sub ex)
end

let default_mapper = {
  constant = Cnst.map;
  expr = E.map;
  pat = P.map;
  typ = T.map;
  data = D.map;
  constructor = C.map;
  location = (fun _ x -> x);
  import = I.map;
  export = EX.map;
  export_data = EXD.map;
  export_all = EX.map_export_all;
  export_data_all = EXD.map_export_data_all;
  value_binding = V.map;
  match_branch = MB.map;
  value_description = VD.map;
  toplevel = TL.map;
}

