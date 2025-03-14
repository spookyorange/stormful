let Hooks = {}

Hooks.HideFlash = {
  mounted() {
    setTimeout(() => {
      this.pushEvent("lv:clear-flash", { key: this.el.dataset.key })
      this.el.style.display = "none"
    }, 5000)
  }
}
Hooks.WindScroller = {
  mounted() {
    this.handleEvent("scroll-to-latest-wind", () => {
      requestAnimationFrame(() => {
        const lastThought = this.el.lastElementChild
        if (lastThought) {
          const inputHeight = 200 // or however tall your input area is
          const targetScroll = lastThought.offsetTop - window.innerHeight + inputHeight + 96 // extra padding for comfort

          window.scrollTo({
            top: targetScroll,
            behavior: 'smooth'
          })
        }
      })
    })
  }
}
Hooks.SensicalityGeneralScroller = {
  mounted() {
    this.el.addEventListener("click", () => {
      window.scrollTo({ top: 0, left: 0, behavior: "smooth" })
    })
  }
}

export default Hooks
