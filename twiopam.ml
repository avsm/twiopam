module FU = OpamfuCli

open Cmdliner

let download_package t output_dir nv =
  let open OpamState.Types in
  let dir =
    let dirname = OpamPackage.to_string nv in
    let cache_subdir = OpamFilename.OP.(output_dir / "cache") in
    OpamFilename.mkdir cache_subdir;
    OpamFilename.OP.(cache_subdir / dirname)
  in
  match OpamProcess.Job.run (OpamAction.download_package t nv) with
  | `Error () -> OpamGlobals.error_and_exit "Download failed"
  | `Successful s ->
      (try OpamAction.extract_package t s nv with Failure _ -> ());
      OpamFilename.move_dir
        ~src:(OpamPath.Switch.build t.root t.switch nv)
        ~dst:dir;
      dir

let changes_files =
 [ "CHANGES.md"; "CHANGES"; "ChangeLog"; "Changes"; "Changelog" ]

let find_changelog t output_dir nv =
  let dir = download_package t output_dir nv in
  let changes_file = ref None in
  List.iter (fun cfile ->
    let fname = OpamFilename.OP.(dir // cfile) in
    if OpamFilename.exists fname then
      changes_file := Some fname
  ) changes_files;
  match !changes_file with
  | None -> None
  | Some cfile ->
      prerr_endline (OpamFilename.to_string cfile);
      let name = "CHANGES-" ^ (OpamPackage.name_to_string nv) ^ ".txt" in
      let dst = OpamFilename.OP.(output_dir // name) in
      OpamFilename.copy ~src:cfile ~dst;
      Some name
    
let run preds idx repos output_dir =
  let open OpamfUniverse in
  let output_dir = OpamFilename.Dir.of_string output_dir in
  let p = of_repositories ~preds idx repos in
  (* let r = index_by_repo p.pkg_idx in *)
  let dates = p.pkgs_dates in
  let pkg_compare (_,a) (_,b) = compare a b in
  let pkgs = List.sort pkg_compare (OpamPackage.Map.bindings dates) in
  (* Filter out the last weeks worth of packages *)
  let month_s = 2592000.0 in
  let week_s = month_s /. 4.0 in
  let duration_s = week_s in
  let current_s = Unix.gettimeofday () in
  let t = OpamState.load_state "source" in
  let summary = Buffer.create 1024 in
  let duration_pkgs = List.filter (fun (_,d) -> (current_s -. duration_s) < d) pkgs in
  List.iter
    (fun (pkg,date) ->
      let info = OpamPackage.Map.find pkg p.pkgs_infos in
      let date =
        match Ptime.of_float_s date with
        | None -> failwith "unexpected date"
        | Some d -> Fmt.strf "%a" Ptime.pp d
      in
      let changes =
        match find_changelog t output_dir pkg with
        | None -> "No CHANGES file found."
        | Some file -> Printf.sprintf "Changes: %s" file
      in
      Printf.bprintf summary "### %s %s\n\nReleased on: %s\n%s\n%s\n%s\n\n"
       (OpamPackage.name_to_string pkg) info.version date info.synopsis
       changes
       (match info.url with
         | None -> ""
         | Some u -> OpamFile.URL.url u |> fun (a,_) -> a);
  ) duration_pkgs;
  let fout = OpamFilename.(OP.(output_dir // "README.md") |> OpamFilename.open_out) in
  Buffer.output_buffer fout summary;
  close_out fout

let cmd =
  let output_dir =
    let doc = "Output directory to store summary and changelogs in" in
    Arg.(value & opt dir "." & info ["d"] ~docv:"OUTPUT_DIR" ~doc)
  in
  let doc = "this week in OPAM" in
  let man = [
    `S "DESCRIPTION";
    `S "BUGS";
    `P "Report them via e-mail to <mirageos-devel@lists.xenproject.org>, or \
        on the issue tracker at <https://github.com/avsm/twiopam/issues>";
  ] in
  Term.(pure run $ FU.pred $ FU.index $ FU.repositories $ output_dir),
  Term.info "twiopam" ~version:"1.0.0" ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
 
