open preamble
     ffiTheory
     asmTheory asmSemTheory asmPropsTheory
     targetSemTheory;

val _ = new_theory"targetProps";

(* TODO: move *)

val SUBSET_IMP = prove(
  ``s SUBSET t ==> (x IN s ==> x IN t)``,
  fs [pred_setTheory.SUBSET_DEF]);

(* -- *)

val asserts_restrict = prove(
  ``!n next1 next2 s P Q.
      (!k. k <= n ==> (next1 k = next2 k)) ==>
      (asserts n next1 s P Q ==> asserts n next2 s P Q)``,
  Induct \\ fs [asserts_def,LET_DEF]
  \\ REPEAT STRIP_TAC \\ POP_ASSUM MP_TAC
  \\ FIRST_X_ASSUM MATCH_MP_TAC
  \\ REPEAT STRIP_TAC
  \\ FIRST_X_ASSUM MATCH_MP_TAC
  \\ DECIDE_TAC);

val shift_interfer_def = Define `
  shift_interfer k s =
    s with next_interfer := shift_seq k s.next_interfer`

val shift_interfer_intro = prove(
  ``shift_interfer k1 (shift_interfer k2 c) =
    shift_interfer (k1+k2) c``,
  fs [shift_interfer_def,shift_seq_def,ADD_ASSOC]);

val evaluate_EQ_evaluate_lemma = prove(
  ``!n ms1 c.
      c.target.get_pc ms1 IN c.prog_addresses /\ c.target.state_ok ms1 /\
      interference_ok c.next_interfer (c.target.proj dm) /\
      (!s ms. c.target.state_rel s ms ==> c.target.state_ok ms) /\
      (!ms1 ms2. (c.target.proj dm ms1 = c.target.proj dm ms2) ==>
                 (c.target.state_ok ms1 = c.target.state_ok ms2)) /\
      (!env.
         interference_ok env (c.target.proj dm) ==>
         asserts n (\k s. env k (c.target.next s)) ms1
           (\ms'. c.target.state_ok ms' /\ c.target.get_pc ms' IN c.prog_addresses)
           (\ms'. c.target.state_rel s2 ms')) ==>
      ?ms2.
        !k. (evaluate c io (k + (n + 1)) ms1 =
             evaluate (shift_interfer (n+1) c) io k ms2) /\
            c.target.state_rel s2 ms2``,
  Induct THEN1
   (fs [] \\ REPEAT STRIP_TAC
    \\ fs [asserts_def,LET_DEF]
    \\ SIMP_TAC std_ss [Once evaluate_def] \\ fs [LET_DEF]
    \\ FIRST_X_ASSUM (MP_TAC o Q.SPEC `K (c.next_interfer 0)`)
    \\ fs [interference_ok_def] \\ RES_TAC \\ fs []
    \\ REPEAT STRIP_TAC \\ RES_TAC \\ fs [shift_interfer_def]
    \\ METIS_TAC [])
  \\ REPEAT STRIP_TAC \\ fs []
  \\ fs [arithmeticTheory.ADD_CLAUSES]
  \\ SIMP_TAC std_ss [Once evaluate_def] \\ fs [ADD1] \\ fs [LET_DEF]
  \\ Q.PAT_ASSUM `!i. bbb`
       (fn th => ASSUME_TAC th THEN MP_TAC (Q.SPEC
         `\i. c.next_interfer 0` th))
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1 (fs [interference_ok_def])
  \\ fs [] \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC bool_ss [GSYM ADD1,asserts_def] \\ fs [LET_DEF]
  \\ `c.target.state_ok (c.target.next ms1)` by METIS_TAC [interference_ok_def] \\ fs []
  \\ Q.PAT_ASSUM `!ms1 c. bbb ==> ?x. bb`
        (MP_TAC o Q.SPECL [`(c.next_interfer 0 (c.target.next ms1))`,
                    `(c with next_interfer := shift_seq 1 c.next_interfer)`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (fs [] \\ REPEAT STRIP_TAC
    THEN1 (fs [interference_ok_def,shift_seq_def])
    THEN1 RES_TAC
    \\ FIRST_X_ASSUM (MP_TAC o Q.SPEC
         `\k. if k = SUC n then c.next_interfer 0 else env k`) \\ fs []
    \\ MATCH_MP_TAC IMP_IMP
    \\ STRIP_TAC THEN1 (fs [interference_ok_def] \\ rw [])
    \\ MATCH_MP_TAC asserts_restrict
    \\ rw [FUN_EQ_THM] \\ `F` by decide_tac)
  \\ REPEAT STRIP_TAC \\ fs [] \\ Q.EXISTS_TAC `ms2` \\ STRIP_TAC
  \\ POP_ASSUM (ASSUME_TAC o Q.SPEC `k`)
  \\ fs [GSYM shift_interfer_def,shift_interfer_intro] \\ fs [GSYM ADD1]);

val enc_ok_not_empty = prove(
  ``enc_ok enc c /\ asm_ok w c ==> (enc w <> [])``,
  METIS_TAC [listTheory.LENGTH_NIL,enc_ok_def]);

val asserts_WEAKEN = prove(
  ``!n next s P Q.
      (!x. P x ==> P' x) /\ (!k. k <= n ==> (next k = next' k)) ==>
      asserts n next s P Q ==>
      asserts n next' s P' Q``,
  Induct \\ fs [asserts_def,LET_DEF] \\ REPEAT STRIP_TAC \\ RES_TAC
  \\ `!k. k <= n ==> (next k = next' k)` by ALL_TAC \\ RES_TAC
  \\ REPEAT STRIP_TAC \\ FIRST_X_ASSUM MATCH_MP_TAC \\ decide_tac);

val bytes_in_memory_IMP_SUBSET = prove(
  ``!xs pc. bytes_in_memory pc xs m d ==> all_pcs (LENGTH xs) pc SUBSET d``,
  Induct \\ fs [all_pcs_def,bytes_in_memory_def]);

val asm_step_IMP_evaluate_step = store_thm("asm_step_IMP_evaluate_step",
  ``!c s1 ms1 io i s2.
      backend_correct c.target /\
      (c.prog_addresses = s1.mem_domain) /\
      interference_ok c.next_interfer (c.target.proj s1.mem_domain) /\
      asm_step c.target.encode c.target.config s1 i s2 /\
      (s2 = asm i (s1.pc + n2w (LENGTH (c.target.encode i))) s1) /\
      c.target.state_rel (s1:'a asm_state) (ms1:'state) ==>
      ?l ms2. !k. (evaluate c io (k + l) ms1 =
                   evaluate (shift_interfer l c) io k ms2) /\
                  c.target.state_rel s2 ms2 /\ l <> 0``,
  fs [backend_correct_def] \\ REPEAT STRIP_TAC \\ RES_TAC
  \\ fs [] \\ NTAC 2 (POP_ASSUM (K ALL_TAC))
  \\ Q.EXISTS_TAC `n+1` \\ fs []
  \\ MATCH_MP_TAC (GEN_ALL evaluate_EQ_evaluate_lemma) \\ fs []
  \\ Q.EXISTS_TAC `s1.mem_domain` \\ fs []
  \\ REPEAT STRIP_TAC \\ TRY (RES_TAC \\ NO_TAC)
  THEN1 (fs [asm_step_def] \\ IMP_RES_TAC enc_ok_not_empty
         \\ Cases_on `c.target.encode i` \\ fs [bytes_in_memory_def])
  \\ fs [LET_DEF] \\ Q.PAT_ASSUM `!k. bb` (K ALL_TAC)
  \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPECL [`\k. env (n - k)`]) \\ fs []
  \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`\k. env (n - k)`]) \\ fs []
  \\ MATCH_MP_TAC IMP_IMP
  \\ STRIP_TAC THEN1 fs [interference_ok_def]
  \\ MATCH_MP_TAC asserts_WEAKEN \\ fs []
  \\ SRW_TAC [] [] \\ fs []
  THEN1 (POP_ASSUM MP_TAC \\ MATCH_MP_TAC SUBSET_IMP
         \\ fs [asm_step_def] \\ IMP_RES_TAC bytes_in_memory_IMP_SUBSET)
  \\ fs [FUN_EQ_THM] \\ REPEAT STRIP_TAC
  \\ `n - (n - k) = k` by decide_tac \\ fs [])
  |> SIMP_RULE std_ss [GSYM PULL_FORALL];

(* basic properties *)

val evaluate_without_TimeOut = store_thm("evaluate_without_TimeOut",
  ``!k k'.
      FST (evaluate mc_conf ffi k ms) <> TimeOut ==>
      (evaluate mc_conf ffi (k + k') ms =
       evaluate mc_conf ffi k ms)``,
  cheat (* easy *));

val evaluate_TimeOut = store_thm("evaluate_TimeOut",
  ``!k k'.
      (evaluate mc_conf ffi (k + k') ms = (TimeOut,s,i)) /\
      i.final_event = NONE ==>
      ?s' i'. (evaluate mc_conf ffi k ms) = (TimeOut,s',i') /\
              i'.final_event = NONE``,
  cheat (* easy *));

val evaluate_TimeOut_or_not = store_thm("evaluate_TimeOut_or_not",
  ``FST (evaluate mc_conf ffi k ms) <> TimeOut /\
    (FST (evaluate mc_conf ffi' k ms) = TimeOut) ==>
    (FST (evaluate mc_conf ffi k ms) = Error)``,
  cheat (* easy *));

val evaluate_IO_mismatch = store_thm("evaluate_IO_mismatch",
  ``(evaluate mc_conf ffi k ms = (Error,ms2,new_ffi)) ==>
    (new_io = NONE)``,
  cheat (* easy *));

val _ = export_theory();
