(* Copyright (c) 2016 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

let cache_subdir = "cache"

let download_package t output_dir nv =
  let open OpamState.Types in
  let dir =
    let dirname = OpamPackage.to_string nv in
    let cache_subdir = OpamFilename.OP.(output_dir / cache_subdir) in
    OpamFilename.mkdir cache_subdir;
    OpamFilename.OP.(cache_subdir / dirname)
  in
  match OpamProcess.Job.run (OpamAction.download_package t nv) with
  | `Error () -> OpamGlobals.error_and_exit "Download failed"
  | `Successful s ->
      (try OpamAction.extract_package t s nv with Failure _ -> ());
      OpamSystem.remove_dir (OpamFilename.Dir.to_string dir);
      OpamFilename.move_dir
        ~src:(OpamPath.Switch.build t.root t.switch nv)
        ~dst:dir;
      dir

let changes_files =
 [ "CHANGES.md"; "CHANGES"; "ChangeLog"; "Changes"; "Changelog" ]

let try_finalize f finally =
  let res = try f () with exn -> finally (); raise exn in
  finally ();
  res

let find_changelog t output_dir nv =
  let dir = download_package t output_dir nv in
  try_finalize (fun () ->
    let changes_file = ref None in
    List.iter (fun cfile ->
      let fname = OpamFilename.OP.(dir // cfile) in
      if OpamFilename.exists fname &&
         Unix.((stat (OpamFilename.to_string fname)).st_size) > 0 then
        changes_file := Some fname
    ) changes_files;
    match !changes_file with
    | None -> None
    | Some cfile ->
        prerr_endline (OpamFilename.to_string cfile);
        let name = "changes-" ^ (OpamPackage.name_to_string nv) ^ ".txt" in
        let dst = OpamFilename.OP.(output_dir // name) in
        OpamFilename.copy ~src:cfile ~dst;
        Some name
  ) (fun () -> OpamSystem.remove_dir (OpamFilename.Dir.to_string dir))
    
let run preds idx repos output_dir duration end_date opam_base_href =
  let open OpamfUniverse in
  let output_dir = OpamFilename.Dir.of_string output_dir in
  let p = of_repositories ~preds idx repos in
  (* let r = index_by_repo p.pkg_idx in *)
  let dates = p.pkgs_dates in
  let pkg_compare (_,b) (_,a) = compare a b in
  let pkgs = List.sort pkg_compare (OpamPackage.Map.bindings dates) in
  (* Filter out the last weeks worth of packages *)
  let duration_s = 
    match duration with
    |`Day -> 86400.
    |`Week -> 86400. *. 7.
    |`Month -> 86400. *. 31.
    |`Year -> 86400. *. 365.
  in
  let current_s = CalendarLib.Date.to_unixfloat end_date in
  let t = OpamState.load_state "source" in
  let summary = Buffer.create 1024 in
  Buffer.add_string summary
   (Printf.sprintf "# This %s in OPAM releases (%s)\n\n"
     (match duration with |`Day -> "day" |`Week -> "week" |`Month -> "month" |`Year -> "year")
     (CalendarLib.Printer.Date.sprint "%a %b %d %Y" end_date));
  let duration_pkgs =
    List.filter (fun (_,d) ->
     (d < current_s) &&
     ((current_s -. duration_s) < d)) pkgs in
  List.iter
    (fun (pkg,date) ->
      let info = OpamPackage.Map.find pkg p.pkgs_infos in
      let date =
        CalendarLib.Date.from_unixfloat date |>
        CalendarLib.Printer.Date.sprint "%a %b %d %Y" 
      in
      let changes =
        match find_changelog t output_dir pkg with
        | None -> "Unknown"
        | Some file -> Printf.sprintf "[%s](#file-changes-%s-txt)" file (OpamPackage.name_to_string pkg)
      in
      Printf.bprintf summary "### %s %s\n\n* *Released on:* %s\n* *Synopsis*: %s\n* *More Info*: [OPAM Page](%s) or [Source Code](%s)\n* *Changes*: %s\n\n"
       (OpamPackage.name_to_string pkg)
       info.version
       date
       info.synopsis
       (Printf.sprintf "%s/%s" opam_base_href (Uri.to_string info.href))
       (match info.url with
         | None -> ""
         | Some u -> OpamFile.URL.url u |> fun (a,_) -> a)
       changes
  ) duration_pkgs;
  let fout = OpamFilename.(OP.(output_dir // "README.md") |> OpamFilename.open_out) in
  Buffer.output_buffer fout summary;
  close_out fout;
  OpamSystem.remove_dir (OpamFilename.(Dir.to_string (OP.(output_dir / cache_subdir))))

open Cmdliner

let todays_date = CalendarLib.Date.from_unixfloat (Unix.gettimeofday ())

let date_term : CalendarLib.Printer.Date.t Arg.converter =
  let parse s =
    try 
     let v = match s with
     |"today" -> todays_date
     | x -> CalendarLib.Printer.Date.from_fstring "%F" x
     in `Ok v
    with exn -> `Error (Printexc.to_string exn)
  in
  let print fmt s = CalendarLib.Printer.Date.fprint "%F" fmt s in
  parse, print
 
let cmd =
  let output_dir =
    let doc = "Output directory to store summary and changelogs in." in
    Arg.(value & opt dir "." & info ["o"] ~docv:"OUTPUT_DIR" ~doc)
  in
  let opam_base_href =
    let doc = "Base URI to use for the OPAM metadata page links." in
    Arg.(value & opt string "https://opam.ocaml.org" & info ["base-href"] ~docv:"BASE_HREF" ~doc)
  in
  let duration =
    let doc = "Duration to go back in time for the report ($(i,day), $(i,week), $(i,month), $(i,year))" in
    let opts = Arg.enum ["day", `Day; "week",`Week; "month",`Month; "year",`Year] in
    Arg.(value & opt opts `Week & info ["t";"time"] ~docv:"TIMESPAN" ~doc)
  in
  let end_date =
    let doc = "End date for the logger in YYYY-MM-DD format or 'today' for current day." in
    Arg.(value & opt date_term todays_date & info ["d";"end-date"] ~docv:"START_DATE" ~doc)
  in
  let doc = "this week in OPAM" in
  let man = [
    `S "DESCRIPTION";
    `S "BUGS";
    `P "Report them via e-mail to <mirageos-devel@lists.xenproject.org>, or \
        on the issue tracker at <https://github.com/avsm/twiopam/issues>";
  ] in
  let module FU = OpamfuCli in
  Term.(pure run $ FU.pred $ FU.index $ FU.repositories $ output_dir $ duration $ end_date $ opam_base_href),
  Term.info "twiopam" ~version:"1.0.0" ~doc ~man

let () =
  match Term.eval cmd with
  | `Error _ -> exit 1
  | _ -> exit 0
 
