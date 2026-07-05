module TUI
  abstract class ListDataSource
    abstract def size : Int32
    abstract def title(filter : String, sort_key : Symbol) : String
    abstract def sort_keys : Array(Symbol)
    abstract def reload(filter : String, sort : Symbol) : Nil
  end
end
