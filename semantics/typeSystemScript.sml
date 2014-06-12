(*Generated by Lem from typeSystem.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasives_extraTheory libTheory astTheory semanticPrimitivesTheory;

val _ = numLib.prefer_num();



val _ = new_theory "typeSystem"

(*open import Pervasives_extra*)
(*open import Lib*)
(*open import Ast*)

(* Only to get check_dup_ctors *)
(*open import SemanticPrimitives*) 

(* Check that the free type variables are in the given list.  Every deBruijn
 * variable must be smaller than the first argument.  So if it is 0, no deBruijn
 * indices are permitted. *)
(*val check_freevars : nat -> list tvarN -> t -> bool*)
 val check_freevars_defn = Hol_defn "check_freevars" `

(check_freevars dbmax tvs (Tvar tv) =  
(MEM tv tvs))
/\
(check_freevars dbmax tvs (Tapp ts tn) =  
(EVERY (check_freevars dbmax tvs) ts))
/\
(check_freevars dbmax tvs (Tvar_db n) = (n < dbmax))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn check_freevars_defn;

(* Simultaneous substitution of types for type variables in a type *)
(*val type_subst : env tvarN t -> t -> t*)
 val type_subst_defn = Hol_defn "type_subst" `

(type_subst s (Tvar tv) =  
((case lookup tv s of
      NONE => Tvar tv
    | SOME(t) => t
  )))
/\
(type_subst s (Tapp ts tn) =  
(Tapp (MAP (type_subst s) ts) tn))
/\
(type_subst s (Tvar_db n) = (Tvar_db n))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn type_subst_defn;

(* Increment the deBruijn indices in a type by n levels, skipping all levels
 * less than skip. *)
(*val deBruijn_inc : nat -> nat -> t -> t*)
 val deBruijn_inc_defn = Hol_defn "deBruijn_inc" `

(deBruijn_inc skip n (Tvar tv) = (Tvar tv))
/\
(deBruijn_inc skip n (Tvar_db m) =  
(if m < skip then
    Tvar_db m
  else
    Tvar_db (m + n)))
/\
(deBruijn_inc skip n (Tapp ts tn) = (Tapp (MAP (deBruijn_inc skip n) ts) tn))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn deBruijn_inc_defn;

(* skip the lowest given indices and replace the next (LENGTH ts) with the given types and reduce all the higher ones *)
(*val deBruijn_subst : nat -> list t -> t -> t*)
 val deBruijn_subst_defn = Hol_defn "deBruijn_subst" `

(deBruijn_subst skip ts (Tvar tv) = (Tvar tv))
/\
(deBruijn_subst skip ts (Tvar_db n) =  
(if ~ (n < skip) /\ (n < (LENGTH ts + skip)) then
    EL (n - skip) ts
  else if ~ (n < skip) then
    Tvar_db (n - LENGTH ts)
  else
    Tvar_db n))
/\
(deBruijn_subst skip ts (Tapp ts' tn) =  
(Tapp (MAP (deBruijn_subst skip ts) ts') tn))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn deBruijn_subst_defn;

(* constructor type environments: each constructor has a type
 * forall tyvars. t list -> (tyvars) typeN *)
val _ = type_abbrev( "flat_tenvC" , ``: (conN, ( tvarN list # t list # tid_or_exn)) env``);
val _ = type_abbrev( "tenvC" , ``: (modN, flat_tenvC) env # flat_tenvC``);

(*val merge_tenvC : tenvC -> tenvC -> tenvC*)
val _ = Define `
 (merge_tenvC (mcenv1,cenv1) (mcenv2,cenv2) = 
  (merge mcenv1 mcenv2, merge cenv1 cenv2))`;


(* Type environments *)
val _ = Hol_datatype `
 tenvE =
    Empty
  (* Binds several de Bruijn type variables *)
  | Bind_tvar of num => tenvE
  (* The number is how many de Bruijn type variables the typescheme binds *)
  | Bind_name of varN => num => t => tenvE`;


val _ = type_abbrev( "tenvM" , ``: (modN, ( (varN, (num # t))env)) env``);

val _ = Define `
 (bind_tvar tvs tenv = (if tvs = 0 then tenv else Bind_tvar tvs tenv))`;


(*val lookup_tenv : varN -> nat -> tenvE -> maybe (nat * t)*) 
 val _ = Define `

(lookup_tenv n inc Empty = NONE)
/\
(lookup_tenv n inc (Bind_tvar tvs e) = (lookup_tenv n (inc + tvs) e))
/\
(lookup_tenv n inc (Bind_name n' tvs t e) =  
(if n' = n then
    SOME (tvs, deBruijn_inc tvs inc t)
  else
    lookup_tenv n inc e))`;


(*val bind_tenv : varN -> nat -> t -> tenvE -> tenvE*)
val _ = Define `
 (bind_tenv n tvs t e = (Bind_name n tvs t e))`;


(*val opt_bind_tenv : maybe varN -> nat -> t -> tenvE -> tenvE*)
val _ = Define `
 (opt_bind_tenv n tvs t e =  
 ((case n of
      NONE => e
    | SOME n' => Bind_name n' tvs t e
  )))`;


(*val t_lookup_var_id : id varN -> tenvM -> tenvE -> maybe (nat * t)*)
val _ = Define `
 (t_lookup_var_id id tenvM tenvE =  
((case id of
      Short x => lookup_tenv x( 0) tenvE
    | Long x y =>
        (case lookup x tenvM of
            NONE => NONE
          | SOME tenvE' => lookup y tenvE'
        )
  )))`;


(*val num_tvs : tenvE -> nat*)
 val _ = Define `
 
(num_tvs Empty =( 0))
/\
(num_tvs (Bind_tvar tvs e) = (tvs + num_tvs e))
/\
(num_tvs (Bind_name n tvs t e) = (num_tvs e))`;


(*val bind_var_list : nat -> list (varN * t) -> tenvE -> tenvE*)
 val _ = Define `

(bind_var_list tvs [] tenv = tenv)
/\
(bind_var_list tvs ((n,t)::binds) tenv =  
(bind_tenv n tvs t (bind_var_list tvs binds tenv)))`;


(*val bind_var_list2 : env varN (nat * t) -> tenvE -> tenvE*)
 val _ = Define `

(bind_var_list2 [] tenv = tenv)
/\
(bind_var_list2 ((n,(tvs,t))::binds) tenv =  
(bind_tenv n tvs t (bind_var_list2 binds tenv)))`;


(* A pattern matches values of a certain type and extends the type environment
 * with the pattern's binders. The number is the maximum deBruijn type variable
 * allowed. *)
(*val type_p : nat -> tenvC -> pat -> t -> list (varN * t) -> bool*)

(* An expression has a type *)
(*val type_e : tenvM -> tenvC -> tenvE -> exp -> t -> bool*)

(* A list of expressions has a list of types *)
(*val type_es : tenvM -> tenvC -> tenvE -> list exp -> list t -> bool*)

(* Type a mutually recursive bundle of functions.  Unlike pattern typing, the
 * resulting environment does not extend the input environment, but just
 * represents the functions *)
(*val type_funs : tenvM -> tenvC -> tenvE -> list (varN * varN * exp) ->
                list (varN * t) -> bool*)

val _ = type_abbrev( "decls" , ``: modN set # ( typeN id) set # ( conN id) set``);

(*val empty_decls : decls*)
val _ = Define `
 (empty_decls = ({},{},{}))`;


(*val union_decls : decls -> decls -> decls*)
val _ = Define `
 (union_decls (m1,t1,e1) (m2,t2,e2) =
  ((m1 UNION m2), (t1 UNION t2), (e1 UNION e2)))`;


(* Check a declaration and update the top-level environments
 * The arguments are in order:
 * - the module that the declaration is in
 * - the set of all modules, and types, and exceptions that have been previously declared
 * - the type schemes of bindings in previous modules
 * - the types of each constructor binding
 * - the type schemes of top-level bindings (plus those in the current module)
 * - the declaration
 * - the set of all modules, and types, and exceptions that have been previously declared and are declared here (cumulative)
 * - the types of the new constructors
 * - the type schemes of the new bindings *)

(*val type_d : maybe modN -> decls -> tenvM -> tenvC -> tenvE -> dec -> decls -> flat_tenvC -> env varN (nat * t) -> bool*)

(*val type_ds : maybe modN -> decls -> tenvM -> tenvC -> tenvE -> list dec -> decls -> flat_tenvC -> env varN (nat * t) -> bool*)
(*val weakE : env varN (nat * t) -> env varN (nat * t) -> bool*)
(*val check_signature : maybe modN -> decls -> flat_tenvC -> env varN (nat * t) -> maybe specs -> decls -> flat_tenvC -> env varN (nat * t) -> bool*)
(*val type_specs : maybe modN -> specs -> decls -> flat_tenvC -> env varN (nat * t) -> bool*)
(*val type_prog : decls -> tenvM -> tenvC -> tenvE -> list top -> decls -> tenvM -> tenvC -> env varN (nat * t) -> bool*)

(* Check that the operator can have type (t1 -> ... -> tn -> t) *)
(*val type_op : op -> list t -> t -> bool*)
val _ = Define `
 (type_op op ts t =  
((case (op,ts) of
      (Opapp, [Tapp [t2'; t3'] TC_fn; t2]) => (t2 = t2') /\ (t = t3')
    | (Opn _, [Tapp [] TC_int; Tapp [] TC_int]) => (t = Tint)
    | (Opb _, [Tapp [] TC_int; Tapp [] TC_int]) => (t = Tbool)
    | (Equality, [t1; t2]) => (t1 = t2) /\ (t = Tbool)
    | (Opassign, [Tapp [t1] TC_ref; t2]) => (t1 = t2) /\ (t = Tunit)
    | (Opref, [t1]) => (t = Tapp [t1] TC_ref)
    | (Opderef, [Tapp [t1] TC_ref]) => (t = t1)
    | (Aalloc, [Tapp [] TC_int; Tapp [] TC_word8]) => (t = Tapp [] TC_word8array)
    | (Asub, [Tapp [] TC_word8array; Tapp [] TC_int]) => (t = Tapp [] TC_word8)
    | (Alength, [Tapp [] TC_word8array]) => (t = Tapp [] TC_int)
    | (Aupdate, [Tapp [] TC_word8array; Tapp [] TC_int; Tapp [] TC_word8]) => t = Tapp [] TC_unit
    | _ => F
  )))`;


(* Check that a type definition defines no already defined types or duplicate
 * constructors, and that the free type variables of each constructor argument
 * type are included in the type's type parameters. *)
(*val check_ctor_tenv :
   maybe modN -> list (list tvarN * typeN * list (conN * list t)) -> bool*)
val _ = Define `
 (check_ctor_tenv mn tds =  
(check_dup_ctors tds /\  
  EVERY
    (\ (tvs,tn,ctors) . 
       ALL_DISTINCT tvs /\
       EVERY
         (\ (cn,ts) .  (EVERY (check_freevars( 0) tvs) ts))
         ctors)
    tds /\  
  ALL_DISTINCT (MAP (\p4055 .  
  (case (p4055 ) of ( (_,tn,_) ) => tn )) tds)))`;


(*val build_ctor_tenv : maybe modN -> list (list tvarN * typeN * list (conN * list t)) -> flat_tenvC*)
val _ = Define `
 (build_ctor_tenv mn tds =  
(REVERSE
    (FLAT
      (MAP
         (\ (tvs,tn,ctors) . 
            MAP (\ (cn,ts) .  (cn,(tvs,ts, TypeId (mk_id mn tn)))) ctors)
         tds))))`;


(* Check that an exception definition defines no already defined (or duplicate)
 * constructors, and that the arguments have no free type variables. *)
(*val check_exn_tenv : maybe modN -> conN -> list t -> bool*)
val _ = Define `
 (check_exn_tenv mn cn ts =  
(EVERY (check_freevars( 0) []) ts))`;


(* For the value restriction on let-based polymorphism *)
(*val is_value : exp -> bool*)
 val is_value_defn = Hol_defn "is_value" `
 
(is_value (Lit _) = T)
/\
(is_value (Con _ es) = (EVERY is_value es))
/\
(is_value (Var _) = T)
/\
(is_value (Fun _ _) = T)
/\
(is_value _ = F)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn is_value_defn;

(*val tid_exn_to_tc : tid_or_exn -> tctor*)
val _ = Define `
 (tid_exn_to_tc t =  
((case t of
      TypeId tid => TC_name tid
    | TypeExn _ => TC_exn
  )))`;


val _ = Hol_reln ` (! tvs cenv n t.
(check_freevars tvs [] t)
==>
type_p tvs cenv (Pvar n) t [(n,t)])

/\ (! tvs cenv b.
T
==>
type_p tvs cenv (Plit (Bool b)) Tbool [])

/\ (! tvs cenv n.
T
==>
type_p tvs cenv (Plit (IntLit n)) Tint [])

/\ (! tvs cenv s.
T
==>
type_p tvs cenv (Plit (StrLit s)) Tstring [])

/\ (! tvs cenv.
T
==>
type_p tvs cenv (Plit Unit) Tunit [])

/\ (! tvs cenv w.
T
==>
type_p tvs cenv (Plit (Word8 w)) Tword8 [])

/\ (! tvs cenv cn ps ts tvs' tn ts' tenv.
(EVERY (check_freevars tvs []) ts' /\
(LENGTH ts' = LENGTH tvs') /\
type_ps tvs cenv ps (MAP (type_subst (ZIP (tvs', ts'))) ts) tenv /\
(lookup_con_id cn cenv = SOME (tvs', ts, tn)))
==>
type_p tvs cenv (Pcon (SOME cn) ps) (Tapp ts' (tid_exn_to_tc tn)) tenv)

/\ (! tvs cenv ps ts tenv.
(type_ps tvs cenv ps ts tenv)
==>
type_p tvs cenv (Pcon NONE ps) (Tapp ts TC_tup) tenv)

/\ (! tvs cenv p t tenv.
(type_p tvs cenv p t tenv)
==>
type_p tvs cenv (Pref p) (Tref t) tenv)

/\ (! tvs cenv.
T
==>
type_ps tvs cenv [] [] [])

/\ (! tvs cenv p ps t ts tenv tenv'.
(type_p tvs cenv p t tenv /\
type_ps tvs cenv ps ts tenv')
==>
type_ps tvs cenv (p::ps) (t::ts) (tenv'++tenv))`;

val _ = Hol_reln ` (! menv cenv tenv b.
T
==>
type_e menv cenv tenv (Lit (Bool b)) Tbool)

/\ (! menv cenv tenv n.
T
==>
type_e menv cenv tenv (Lit (IntLit n)) Tint)

/\ (! menv cenv tenv s.
T
==>
type_e menv cenv tenv (Lit (StrLit s)) Tstring)

/\ (! menv cenv tenv.
T
==>
type_e menv cenv tenv (Lit Unit) Tunit)

/\ (! menv cenv tenv w.
T
==>
type_e menv cenv tenv (Lit (Word8 w)) Tword8)

/\ (! menv cenv tenv e t.
(check_freevars (num_tvs tenv) [] t /\
type_e menv cenv tenv e Texn) 
==>
type_e menv cenv tenv (Raise e) t)

/\ (! menv cenv tenv e pes t.
(type_e menv cenv tenv e t /\ ~ (pes = []) /\
(! ((p,e) :: LIST_TO_SET pes). ? tenv'.
   ALL_DISTINCT (pat_bindings p []) /\   
   type_p (num_tvs tenv) cenv p Texn tenv' /\
   type_e menv cenv (bind_var_list( 0) tenv' tenv) e t))
==>
type_e menv cenv tenv (Handle e pes) t)

/\ (! menv cenv tenv cn es tvs tn ts' ts.
(EVERY (check_freevars (num_tvs tenv) []) ts' /\
(LENGTH tvs = LENGTH ts') /\
type_es menv cenv tenv es (MAP (type_subst (ZIP (tvs, ts'))) ts) /\
(lookup_con_id cn cenv = SOME (tvs, ts, tn)))
==>
type_e menv cenv tenv (Con (SOME cn) es) (Tapp ts' (tid_exn_to_tc tn)))

/\ (! menv cenv tenv es ts.
(type_es menv cenv tenv es ts)
==>
type_e menv cenv tenv (Con NONE es) (Tapp ts TC_tup))

/\ (! menv cenv tenv n t targs tvs.
((tvs = LENGTH targs) /\
EVERY (check_freevars (num_tvs tenv) []) targs /\
(t_lookup_var_id n menv tenv = SOME (tvs,t)))
==>
type_e menv cenv tenv (Var n) (deBruijn_subst( 0) targs t))

/\ (! menv cenv tenv n e t1 t2.
(check_freevars (num_tvs tenv) [] t1 /\
type_e menv cenv (bind_tenv n( 0) t1 tenv) e t2)
==>
type_e menv cenv tenv (Fun n e) (Tfn t1 t2))

/\ (! menv cenv tenv op es ts t.
(type_es menv cenv tenv es ts /\
type_op op ts t) 
==>
type_e menv cenv tenv (App op es) t)

/\ (! menv cenv tenv l e1 e2.
(type_e menv cenv tenv e1 Tbool /\
type_e menv cenv tenv e2 Tbool)
==>
type_e menv cenv tenv (Log l e1 e2) Tbool)

/\ (! menv cenv tenv e1 e2 e3 t.
(type_e menv cenv tenv e1 Tbool /\
(type_e menv cenv tenv e2 t /\
type_e menv cenv tenv e3 t))
==>
type_e menv cenv tenv (If e1 e2 e3) t)

/\ (! menv cenv tenv e pes t1 t2.
(type_e menv cenv tenv e t1 /\ ~ (pes = []) /\
(! ((p,e) :: LIST_TO_SET pes) . ? tenv'.
   ALL_DISTINCT (pat_bindings p []) /\   
   type_p (num_tvs tenv) cenv p t1 tenv' /\
   type_e menv cenv (bind_var_list( 0) tenv' tenv) e t2))
==>
type_e menv cenv tenv (Mat e pes) t2)

/\ (! menv cenv tenv n e1 e2 t1 t2 tvs.
(is_value e1 /\
type_e menv cenv (bind_tvar tvs tenv) e1 t1 /\
type_e menv cenv (opt_bind_tenv n tvs t1 tenv) e2 t2)
==>
type_e menv cenv tenv (Let n e1 e2) t2)

/\ (! menv cenv tenv n e1 e2 t1 t2.
(type_e menv cenv tenv e1 t1 /\
type_e menv cenv (opt_bind_tenv n( 0) t1 tenv) e2 t2)
==>
type_e menv cenv tenv (Let n e1 e2) t2)

/\ (! menv cenv tenv funs e t tenv' tvs.
(type_funs menv cenv (bind_var_list( 0) tenv' (bind_tvar tvs tenv)) funs tenv' /\
type_e menv cenv (bind_var_list tvs tenv' tenv) e t)
==>
type_e menv cenv tenv (Letrec funs e) t)

/\ (! menv cenv tenv.
T
==>
type_es menv cenv tenv [] [])

/\ (! menv cenv tenv e es t ts.
(type_e menv cenv tenv e t /\
type_es menv cenv tenv es ts)
==>
type_es menv cenv tenv (e::es) (t::ts))

/\ (! menv cenv env.
T
==>
type_funs menv cenv env [] [])

/\ (! menv cenv env fn n e funs env' t1 t2.
(check_freevars (num_tvs env) [] (Tfn t1 t2) /\
type_e menv cenv (bind_tenv n( 0) t1 env) e t2 /\
type_funs menv cenv env funs env' /\
(lookup fn env' = NONE))
==>
type_funs menv cenv env ((fn, n, e)::funs) ((fn, Tfn t1 t2)::env'))`;

(*val tenv_add_tvs : nat -> env varN t -> env varN (nat * t)*)
val _ = Define `
 (tenv_add_tvs tvs tenv =  
(MAP (\ (n,t) .  (n,(tvs,t))) tenv))`;


val _ = Hol_reln ` (! tvs mn menv cenv tenv p e t tenv' decls.
(is_value e /\
ALL_DISTINCT (pat_bindings p []) /\
type_p tvs cenv p t tenv' /\
type_e menv cenv (bind_tvar tvs tenv) e t)
==>
type_d mn decls menv cenv tenv (Dlet p e) empty_decls emp (tenv_add_tvs tvs tenv'))

/\ (! mn menv cenv tenv p e t tenv' decls.
(ALL_DISTINCT (pat_bindings p []) /\
type_p( 0) cenv p t tenv' /\
type_e menv cenv tenv e t)
==>
type_d mn decls menv cenv tenv (Dlet p e) empty_decls emp (tenv_add_tvs( 0) tenv'))

/\ (! mn menv cenv tenv funs tenv' tvs decls.
(type_funs menv cenv (bind_var_list( 0) tenv' (bind_tvar tvs tenv)) funs tenv')
==>
type_d mn decls menv cenv tenv (Dletrec funs) empty_decls emp (tenv_add_tvs tvs tenv'))

/\ (! mn menv cenv tenv tdefs mdecls edecls tdecls new_tdecls.
(check_ctor_tenv mn tdefs /\
(new_tdecls = LIST_TO_SET (MAP (\ (tvs,tn,ctors) .  (mk_id mn tn)) tdefs)) /\
DISJOINT new_tdecls tdecls)
==>
type_d mn (mdecls,tdecls,edecls) menv cenv tenv (Dtype tdefs) ({},new_tdecls,{}) (build_ctor_tenv mn tdefs) emp)

/\ (! mn menv cenv tenv cn ts mdecls edecls tdecls.
(check_exn_tenv mn cn ts /\
~ (mk_id mn cn IN edecls))
==>
type_d mn (mdecls,tdecls,edecls) menv cenv tenv (Dexn cn ts) ({},{},{mk_id mn cn}) (bind cn ([], ts, TypeExn (mk_id mn cn)) emp) emp)`;
 
val _ = Hol_reln ` (! mn menv cenv tenv decls.
T
==>
type_ds mn decls menv cenv tenv [] empty_decls emp emp)

/\ (! mn menv cenv tenv d ds cenv' tenv' cenv'' tenv'' decls decls' decls''.
(type_d mn decls menv cenv tenv d decls' cenv' tenv' /\
type_ds mn (union_decls decls' decls) menv (merge_tenvC (emp,cenv') cenv) (bind_var_list2 tenv' tenv) ds decls'' cenv'' tenv'')
==>
type_ds mn decls menv cenv tenv (d::ds) (union_decls decls'' decls') (merge cenv'' cenv') (merge tenv'' tenv'))`;

val _ = Hol_reln ` (! mn. 
T
==>
type_specs mn [] empty_decls emp emp)

/\ (! mn x t specs cenv tenv fvs decls.
(check_freevars( 0) fvs t /\
type_specs mn specs decls cenv tenv)
==>
type_specs mn (Sval x t :: specs) decls cenv (tenv ++ [(x, (LENGTH fvs, type_subst (ZIP (fvs, (MAP Tvar_db (GENLIST (\ x .  x) (LENGTH fvs))))) t))])) 

/\ (! mn cenv tenv td specs new_tdecls decls.
(check_ctor_tenv mn td /\
(new_tdecls = LIST_TO_SET (MAP (\ (tvs,tn,ctors) .  (mk_id mn tn)) td)) /\
type_specs mn specs decls cenv tenv)
==>
type_specs mn (Stype td :: specs) (union_decls decls ({},new_tdecls,{})) (merge cenv (build_ctor_tenv mn td)) tenv)

/\ (! mn cenv tenv cn ts specs decls.
(check_exn_tenv mn cn ts /\
type_specs mn specs decls cenv tenv)
==>
type_specs mn (Sexn cn ts :: specs) (union_decls decls ({},{},{mk_id mn cn})) (cenv ++ [(cn,([], ts, TypeExn (mk_id mn cn)))]) tenv)

/\ (! mn cenv tenv tn specs tvs decls.
(ALL_DISTINCT tvs /\
type_specs mn specs decls cenv tenv)
==>
type_specs mn (Stype_opq tvs tn :: specs) (union_decls decls ({},{mk_id mn tn},{})) cenv tenv)`;

val _ = Define `
 (weakE tenv_impl tenv_spec =  
(! x.
    (case lookup x tenv_spec of
        SOME (tvs_spec, t_spec) =>
          (case lookup x tenv_impl of
              NONE => F
            | SOME (tvs_impl, t_impl) =>
                ? subst.                  
 (LENGTH subst = tvs_impl) /\                  
                  check_freevars tvs_impl [] t_impl /\                  
                  EVERY (check_freevars tvs_spec []) subst /\                  
                  (deBruijn_subst( 0) subst t_impl = t_spec)
          )
        | NONE => T
    )))`;


(*val flat_weakC : flat_tenvC -> flat_tenvC -> bool*)
val _ = Define `
 (flat_weakC cenv_impl cenv_spec =  
(! cn.
    (case lookup cn cenv_spec of
        SOME (tvs_spec,ts_spec,tn_spec) =>
          (case lookup cn cenv_impl of
              NONE => F
            | SOME (tvs_impl, ts_impl, tn_impl) =>                
(tn_spec = tn_impl) /\                
(                
                (* For simplicity, we reject matches that differ only by renaming of bound type variables *)tvs_spec = tvs_impl) /\                
                (ts_spec = ts_impl)
          )
      | NONE => T
    )))`;


(*val weak_decls : decls -> decls -> bool*)
val _ = Define `
 (weak_decls (mdecs_impl, tdecs_impl, edecs_impl) (mdecs_spec, tdecs_spec, edecs_spec) =  
  ((mdecs_impl = mdecs_spec) /\  
(tdecs_spec SUBSET tdecs_impl) /\  
(edecs_spec SUBSET edecs_impl)))`;


val _ = Hol_reln ` (! mn cenv tenv decls.
T
==>
check_signature mn decls cenv tenv NONE decls cenv tenv)

/\ (! mn cenv tenv specs tenv' cenv' decls decls'.
(weakE tenv tenv' /\
flat_weakC cenv cenv' /\
weak_decls decls decls' /\
type_specs mn specs decls' cenv' tenv')
==>
check_signature mn decls cenv tenv (SOME specs) decls' cenv' tenv')`;

val _ = Hol_reln ` (! menv cenv tenv d cenv' tenv' decls decls'.
(type_d NONE decls menv cenv tenv d decls' cenv' tenv')
==>
type_top decls menv cenv tenv (Tdec d) decls' emp (emp,cenv') tenv')

/\ (! menv cenv tenv mn spec ds cenv' tenv' cenv'' tenv'' mdecls tdecls edecls decls' mdecls'' tdecls'' edecls''.
(~ (mn IN mdecls) /\
type_ds (SOME mn) (mdecls,tdecls,edecls) menv cenv tenv ds decls' cenv' tenv' /\
check_signature (SOME mn) decls' cenv' tenv' spec (mdecls'',tdecls'',edecls'') cenv'' tenv'')
==>
type_top (mdecls,tdecls,edecls) menv cenv tenv (Tmod mn spec ds) (({mn} UNION mdecls''),tdecls'',edecls'') [(mn,tenv'')] ([(mn,cenv'')], emp) emp)`;

val _ = Hol_reln ` (! menv cenv tenv decls.
T
==>
type_prog decls menv cenv tenv [] empty_decls emp (emp,emp) emp)

/\ (! menv cenv tenv top tops menv' cenv' tenv' menv'' cenv'' tenv'' decls decls' decls''.
(type_top decls menv cenv tenv top decls' menv' cenv' tenv' /\
type_prog (union_decls decls' decls) (merge menv' menv) (merge_tenvC cenv' cenv) (bind_var_list2 tenv' tenv) tops decls'' menv'' cenv'' tenv'')
==>
type_prog decls menv cenv tenv (top :: tops) (union_decls decls'' decls') (merge menv'' menv') (merge_tenvC cenv'' cenv') (merge tenv'' tenv'))`;
val _ = export_theory()

