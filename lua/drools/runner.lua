-- lua/drools/runner.lua
-- Test & Rule execution runner for Maven/Gradle projects containing Drools rules

local M = {}

--- Detect project type and run rule tests
function M.run_tests()
  local root = vim.fs.dirname(vim.fs.find({ "pom.xml", "build.gradle" }, { upward = true })[1])
  if not root then
    vim.notify("No pom.xml or build.gradle found in parent directories", vim.log.levels.ERROR)
    return
  end

  local cmd
  if vim.fn.filereadable(root .. "/pom.xml") == 1 then
    cmd = "mvn test"
  elseif vim.fn.filereadable(root .. "/build.gradle") == 1 then
    cmd = "./gradlew test"
  else
    cmd = "mvn test"
  end

  vim.notify("Executing Drools test suite: " .. cmd, vim.log.levels.INFO)

  -- Open split terminal to execute test command
  vim.cmd("botright 15new")
  vim.fn.termopen(cmd, {
    cwd = root,
    on_exit = function(_, code, _)
      if code == 0 then
        vim.notify("Drools tests passed cleanly!", vim.log.levels.INFO)
      else
        vim.notify("Drools tests failed with exit code " .. code, vim.log.levels.ERROR)
      end
    end,
  })
  vim.cmd("startinsert")
end

return M
