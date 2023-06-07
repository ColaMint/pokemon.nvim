local utf8 = require("util.utf8")

local M = {
    name_color = "cccccc",
    number_color = "cccccc",
    description_color = "cccccc",
    size = nil,
    pokemon = nil,
    win_id = nil,
}

local script_dir = function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

local read_all = function(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

function M.setup(opt)
    local size = opt.size
    if size == nil or size == "auto" then
        local win_height = vim.api.nvim_win_get_height(0)
        if win_height >= 60 then
            size = "large"
        elseif win_height >= 40 then
            size = "small"
        else
            size = "tiny"
        end
    end
    M.size = size

    local pokemon_file
    if opt.number == nil or opt.number == "random" then
        math.randomseed(os.time())
        local pokemon_dir = script_dir() .. "metadata/"
        local pokemon_files = {}
        for value, _ in vim.fs.dir(pokemon_dir) do
            pokemon_files[#pokemon_files + 1] = value
        end
        pokemon_file = pokemon_dir .. pokemon_files[math.random(#pokemon_files)]
    else
        local number = opt.number
        if #number == 4 then
            number = number .. ".1"
        end
        pokemon_file = script_dir() .. "metadata/" .. number .. ".json"
    end

    local content = read_all(pokemon_file)
    M.pokemon = vim.json.decode(content)

    vim.api.nvim_create_user_command("PokemonTogglePokedex", M.toggle_pokedex, {})
end

function M.header()
    return vim.split(M.pokemon["plain_text_art"][M.size], "\n")
end

function M.toggle_pokedex(opt)
    if M.pokemon == nil then
        return
    end

    -- does the floating window still exist?
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, true)
    else
        local pokedex_path = script_dir() .. "metadata/pokedex.json"
        local content = read_all(pokedex_path)
        local pokedex = vim.json.decode(content)

        -- add pokemon to pokedex
        local text_art = M.pokemon.colored_text_art.small
        for i = 1, #text_art do
            local line = ""
            for j = 1, #text_art[i] do
                pokedex[i + 9][j + 4] = text_art[i][j]
            end
        end

        -- add name to pokedex
        for i, c in utf8.codes(M.pokemon.name) do
            pokedex[33][i + 4] = { c, M.name_color }
        end

        -- add number to pokedex
        local number = " #" .. M.pokemon.number .. "." .. M.pokemon.forme
        for i, c in utf8.codes(number) do
            pokedex[33][i + 36] = { c, M.number_color }
        end

        -- add description to pokedex
        for i, c in utf8.codes(M.pokemon.description) do
            row = math.floor((i - 1) / 40)
            col = (i - 1) % 40
            if row > 4 then
                break
            end
            pokedex[row + 35][col + 5] = { c, M.description_color }
        end

        local buf = vim.api.nvim_create_buf(false, true)
        for i = 1, #pokedex do
            -- draw pokedex
            local line = ""
            for j = 1, #pokedex[i] do
                local pixel = pokedex[i][j]
                local char = pixel[1]
                local color = pixel[2]
                local highlight_group = "Pixel_" .. color
                line = line .. char
            end
            vim.api.nvim_buf_set_lines(buf, i - 1, i - 1, false, { line })

            -- set color
            col = 0
            for j = 1, #pokedex[i] do
                local pixel = pokedex[i][j]
                local char = pixel[1]
                local color = pixel[2]
                local highlight_group = "pokemon_" .. color
                vim.api.nvim_set_hl(0, highlight_group, { fg = "#" .. color })
                vim.api.nvim_buf_add_highlight(buf, 0, highlight_group, i - 1, col, col + #char)
                col = col + #char
            end
        end

        -- create a floating window
        local vim_width = vim.api.nvim_get_option("columns")
        local vim_height = vim.api.nvim_get_option("lines")
        local win_width = 48
        local win_height = 40
        local win_id = vim.api.nvim_open_win(buf, false, {
            relative = "editor",
            row = (vim_height / 2) - (win_height / 2),
            col = (vim_width / 2) - (win_width / 2),
            width = win_width,
            height = win_height,
            style = "minimal",
            focusable = false,
            -- border = 'rounded',
        })
        M.win_id = win_id
    end
end

return M
