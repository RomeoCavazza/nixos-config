document.querySelectorAll("form[data-assistant]").forEach((form) => {
  const kind = form.dataset.assistant;
  const button = form.querySelector("button");
  const status = form.closest(".assistant-actions").querySelector(".assistant-status");
  const messageBody = document.querySelector(".message-body");
  const originalBody = messageBody.innerHTML;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (kind === "summary" && messageBody.dataset.mode === "summary") {
      messageBody.innerHTML = originalBody;
      messageBody.dataset.mode = "original";
      button.textContent = "Summarize";
      status.textContent = "";
      return;
    }

    const idleLabel = button.textContent;
    button.disabled = true;
    button.textContent = kind === "summary" ? "Summarizing…" : "Drafting…";
    status.textContent = "";

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        },
        credentials: "same-origin",
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || "Assistant request failed.");

      if (kind === "summary") {
        const summary = document.createElement("p");
        summary.textContent = payload.content;
        messageBody.replaceChildren(summary);
        messageBody.dataset.mode = "summary";
        button.textContent = "Show original";
      } else {
        const reply = document.querySelector("#reply");
        reply.querySelector("textarea").value = payload.content;
        reply.hidden = false;
        button.textContent = "Regenerate reply";
      }
      status.textContent = "Done.";
    } catch (error) {
      status.textContent = error.message;
      button.textContent = idleLabel;
    } finally {
      button.disabled = false;
    }
  });
});
