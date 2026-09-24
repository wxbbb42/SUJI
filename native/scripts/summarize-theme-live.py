#!/usr/bin/env python3
"""Extract bounded, non-response evidence from an ignored synthetic live run.

Raw prompts, responses, receipts and screenshots stay in native/artifacts. This
summary is suitable for review but does not automatically grade content quality.
"""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("report", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
raw = args.report.read_bytes()
data = json.loads(raw)
rows = []
for item in data["results"]:
    usage = []
    for exchange in item.get("exchanges", []):
        try:
            response = json.loads(exchange.get("response", "{}"))
        except (ValueError, TypeError):
            response = {}
        tokens = response.get("usage", {})
        usage.append({
            "httpStatus": exchange.get("status"),
            "networkStarted": "startedAt" in exchange,
            "injectedInterruption": exchange.get("injectedTransportInterruption", False),
            "requestBytes": len(json.dumps(exchange.get("request", {}), ensure_ascii=False).encode()),
            "promptTokens": tokens.get("prompt_tokens"),
            "completionTokens": tokens.get("completion_tokens"),
            "totalTokens": tokens.get("total_tokens"),
        })
    answer = item.get("answer", "")
    receipts = item.get("receipts", [])
    reply = item.get("themeReply") or {}
    rows.append({
        **{key: item.get(key) for key in ["id", "turn", "kind", "profile", "question", "route", "branch", "previousFollowUp", "expectedFailure", "failure", "timedOut", "calculationOK", "closedProtocolOK", "archiveReplayOK", "dossierReused", "retryReceiptsUnchanged"]},
        "action": reply.get("action"), "followUp": reply.get("followUp"),
        "tools": [r.get("name") for r in receipts],
        "receiptCount": len(receipts), "answerCharacters": len(answer),
        "answerSHA256": hashlib.sha256(answer.encode()).hexdigest() if answer else None,
        "receiptsSHA256": hashlib.sha256(json.dumps(receipts, sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
        "exchanges": usage,
        "contentVerdict": "requires-independent-review",
    })
summary = {
    "scope": "Synthetic profiles; real deployed model and production native verifier. T07 initial interruption intentionally injected. No model responses copied.",
    "rawReportPath": str(args.report), "rawReportSHA256": hashlib.sha256(raw).hexdigest(),
    **{key: data.get(key) for key in ["requestBudget", "modelRequests", "attemptedModelRequests", "transportInterruptions", "protocolVersion", "contentVersion"]},
    "scenarioCount": len({r["id"] for r in rows}), "turnCount": len(rows), "results": rows,
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
print(f"Wrote {len(rows)} sanitized turn summaries; content is not auto-passed.")
