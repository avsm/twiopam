module FU = OpamfuCli

open Cmdliner

let run preds idx repos =
  let open OpamfUniverse in
  let p = of_repositories ~preds idx repos in
  let r = index_by_repo p.pkg_idx in
  let dates = p.pkgs_dates in
  OpamPackage.Map.iter 
    (fun pkg date ->
      let date =
        match Ptime.of_float_s date with
        | None -> failwith "unexpected date"
        | Some d -> Format.(Ptime.pp str_formatter d; flush_str_formatter ()) in
      Printf.printf "%s %s\n" (OpamPackage.name_to_string pkg) date
  ) dates


let cmd =
  let doc = "this week in OPAM" in
  let man = [
    `S "DESCRIPTION";
    `S "BUGS";
    `P "Report them via e-mail to <mirageos-devel@lists.xenproject.org>, or \
        on the issue tracker at <https://github.com/avsm/twiopam/issues>";
  ] in
  Term.(pure run $ FU.pred $ FU.index $ FU.repositories),
  Term.info "twiopam" ~version:"1.0.0" ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
 
