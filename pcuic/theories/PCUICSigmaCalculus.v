(* Distributed under the terms of the MIT license.   *)
From Equations Require Import Equations.
From Coq Require Import Bool String List BinPos Compare_dec Omega Lia.
Require Import Coq.Program.Syntax Coq.Program.Basics.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICInduction PCUICLiftSubst PCUICUnivSubst
     PCUICTyping PCUICWeakeningEnv PCUICClosed PCUICReduction.
Require Import ssreflect ssrbool.

(** * Type preservation for σ-calculus *)

Set Asymmetric Patterns.

Section Sigma.

Context `{checker_flags}.

Open Scope sigma_scope.

(* Well-typedness of a substitution *)

Definition well_subst Σ (Γ : context) σ (Δ : context) :=
  forall x decl,
    nth_error Γ x = Some decl ->
    Σ ;;; Δ |- σ x : ((lift0 (S x)) (decl_type decl)).[ σ ].

Notation "Σ ;;; Δ ⊢ σ : Γ" :=
  (well_subst Σ Γ σ Δ) (at level 50, Δ, σ, Γ at next level).

Lemma well_subst_Up :
  forall Σ Γ Δ σ na A,
    Σ ;;; Δ ⊢ σ : Γ ->
    Σ ;;; Δ ,, vass na A.[σ] ⊢ ⇑ σ : Γ ,, vass na A.
Proof.
  intros Σ Γ Δ σ na A h [|n] decl e.
  - simpl in *. inversion e. subst. clear e. simpl.
    (* NEED commutation lemma between lift and inst *)
    admit.
  - simpl in *.
    specialize (h _ _ e).
Admitted.

Lemma well_subst_Up' :
  forall Σ Γ Δ σ na t A,
    Σ ;;; Δ ⊢ σ : Γ ->
    Σ ;;; Δ ,, vdef na t.[σ] A.[σ] ⊢ ⇑ σ : Γ ,, vdef na t A.
Proof.
  intros Σ Γ Δ σ na t A h [|n] decl e.
  - simpl in *. inversion e. subst. clear e. simpl.
    (* NEED commutation lemma between lift and inst *)
    admit.
  - simpl in *.
    specialize (h _ _ e).
Admitted.

(* TODO MOVE *)
Lemma inst_mkApps :
  forall t l σ,
    (mkApps t l).[σ] = mkApps t.[σ] (map (inst σ) l).
Proof.
  intros t l σ.
  induction l in t, σ |- *.
  - reflexivity.
  - simpl. rewrite IHl. reflexivity.
Qed.

Hint Rewrite @inst_mkApps : sigma.

Lemma instantiate_params_inst :
  forall params pars T σ T',
    instantiate_params params pars T = Some T' ->
    instantiate_params params (map (inst σ) pars) T = Some T'.
Proof.
  intros params pars T σ T'.
  unfold instantiate_params.
  generalize (@nil term).
  generalize (List.rev params). clear params.
  intros params s e.
  case_eq (instantiate_params_subst params pars s T) ;
    try solve [ intro bot ; rewrite bot in e ; discriminate e ].
  intros [s' ty] e'. rewrite e' in e. inversion e. subst. clear e.
  induction params in σ, pars, s, T, s', ty, e' |- *.
  - simpl in e'. simpl. destruct pars. all: try discriminate e'.
    inversion e'. subst. clear e'.
    simpl. reflexivity.
  - simpl in e'. simpl.
    case_eq (decl_body a).
    + intros t e. rewrite e in e'.
      destruct T. all: try discriminate e'.
      eapply IHparams in e'. eassumption.
    + intro neq. rewrite neq in e'.
      destruct T. all: try discriminate e'.
      destruct pars. all: try discriminate.
      simpl. eapply IHparams.
      (* Bad generalisation to s, should be inst in the conclusion.
         Of course we also need to fix the general statement.
       *)
Abort.

Lemma types_of_case_inst :
  forall ind mdecl idecl npar args u p pty indctx pctx ps btys σ,
    types_of_case ind mdecl idecl (firstn npar args) u p pty =
    Some (indctx, pctx, ps, btys) ->
    types_of_case ind mdecl idecl (firstn npar (map (inst σ) args)) u p.[σ] pty.[σ] =
    Some (indctx, pctx, ps, btys).
Proof.
  intros ind mdecl idecl npar args u p pty indctx pctx ps btys σ h.
  unfold types_of_case in *.
  case_eq (instantiate_params (ind_params mdecl) (firstn npar args) (ind_type idecl)) ;
    try solve [ intro bot ; rewrite bot in h ; discriminate h ].
  intros ity eity. rewrite eity in h.

  (* case_eq (destArity [] ity) ; *)
  (*   try solve [ intro bot ; rewrite bot in h ; discriminate h ]. *)
  (* intros [args0 ?] ear. rewrite ear in h. *)
  (* case_eq (destArity [] pty) ; *)
  (*   try solve [ intro bot ; rewrite bot in h ; discriminate h ]. *)
  (* intros [args' s'] ear'. rewrite ear' in h. *)
  (* case_eq (map_option_out (build_branches_type ind mdecl idecl (firstn npar args) u p)) ; *)
  (*   try solve [ intro bot ; rewrite bot in h ; discriminate h ]. *)
  (* intros brtys ebrtys. rewrite ebrtys in h. *)
  (* eapply build_branches_type_eq_term in ebrtys as [brtys' [ebrtys' he]] ; eauto. *)
  (* inversion htc. subst. clear htc. *)
  (* rewrite ebrtys'. intuition eauto. *)
Abort.

Lemma type_inst :
  forall Σ Γ Δ σ t A,
    wf Σ.1 ->
    wf_local Σ Γ ->
    wf_local Σ Δ ->
    Σ ;;; Δ ⊢ σ : Γ ->
    Σ ;;; Γ |- t : A ->
    Σ ;;; Δ |- t.[σ] : A.[σ].
Proof.
  intros Σ Γ Δ σ t A hΣ hΓ hΔ hσ h.
  revert Σ hΣ Γ hΓ t A h Δ σ hΔ hσ.
  apply (typing_ind_env (fun Σ Γ t T => forall Δ σ,
    wf_local Σ Δ ->
    Σ ;;; Δ ⊢ σ : Γ ->
    Σ ;;; Δ |- t.[σ] : T.[σ]
  )).
  - intros Σ wfΣ Γ wfΓ n decl e X Δ σ hΔ hσ. simpl.
    eapply hσ. assumption.
  - intros Σ wfΣ Γ wfΓ l X H0 Δ σ hΔ hσ. simpl.
    econstructor. all: assumption.
  - intros Σ wfΣ Γ wfΓ na A B s1 s2 X hA ihA hB ihB Δ σ hΔ hσ.
    autorewrite with sigma. simpl.
    econstructor.
    + eapply ihA ; auto.
    + eapply ihB.
      * econstructor ; auto.
        eexists. eapply ihA ; auto.
      * eapply well_subst_Up. assumption.
  - intros Σ wfΣ Γ wfΓ na A t s1 bty X hA ihA ht iht Δ σ hΔ hσ.
    autorewrite with sigma.
    econstructor.
    + eapply ihA ; auto.
    + eapply iht.
      * econstructor ; auto.
        eexists. eapply ihA ; auto.
      * eapply well_subst_Up. assumption.
  - intros Σ wfΣ Γ wfΓ na b B t s1 A X hB ihB hb ihb ht iht Δ σ hΔ hσ.
    autorewrite with sigma.
    econstructor.
    + eapply ihB. all: auto.
    + eapply ihb. all: auto.
    + eapply iht.
      * econstructor. all: auto.
        -- eexists. eapply ihB. all: auto.
        -- simpl. eapply ihb. all: auto.
      * eapply well_subst_Up'. assumption.
  - intros Σ wfΣ Γ wfΓ t na A B u X ht iht hu ihu Δ σ hΔ hσ.
    autorewrite with sigma.
    (* NEED Relation between inst and subst *)
    admit.
  - intros Σ wfΣ Γ wfΓ cst u decl X X0 isdecl hconst Δ σ hΔ hσ.
    (* autorewrite with sigma. *) simpl.
    (* NEED Commutation *)
    admit.
  - intros Σ wfΣ Γ wfΓ ind u mdecl idecl isdecl X X0 hconst Δ σ hΔ hσ.
    (* autorewrite with sigma. *) simpl.
    (* NEED Commutation *)
    admit.
  - intros Σ wfΣ Γ wfΓ ind i u mdecl idecl cdecl isdecl X X0 hconst Δ σ hΔ hσ.
    (* autorewrite with sigma. *) simpl.
    (* NEED Commutation *)
    admit.
  - intros Σ wfΣ Γ wfΓ ind u npar p c brs args mdecl idecl isdecl X X0 e pars
           pty hp indctx pctx ps btys htoc hca hel ihp hc ihc hbrs Δ σ hΔ hσ.
    autorewrite with sigma. simpl.
    rewrite map_app. simpl.
    rewrite map_skipn.
    eapply type_Case.
    + eassumption.
    + assumption.
    + eapply ihp. all: auto.
    + admit.
    + admit.
    + admit.
    + admit.
    + admit.
  - intros Σ wfΣ Γ wfΓ p c u mdecl idecl pdecl isdecl args X X0 hc ihc e ty
           Δ σ hΔ hσ.
    autorewrite with sigma. simpl.
    admit.
  - intros Σ wfΣ Γ wfΓ mfix n decl types H0 H1 X ihmfix Δ σ hΔ hσ.
    autorewrite with sigma.
    admit.
  - intros Σ wfΣ Γ wfΓ mfix n decl types H0 X X0 ihmfix Δ σ hΔ hσ.
    autorewrite with sigma.
    admit.
  - intros Σ wfΣ Γ wfΓ t A B X ht iht hwf hcu Δ σ hΔ hσ.
    eapply type_Cumul.
    + eapply iht. all: auto.
    + destruct hwf as [[[ctx [s [? ?]]] ?] | [s [? ihB]]].
      * left. eexists _,_. split.
        -- admit.
        -- admit.
      * right. eexists. eapply ihB. all: auto.
    + admit.
Admitted.

End Sigma.