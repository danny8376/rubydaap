require 'mp4info'
require 'dmap'
require 'mongo_sequence'

MongoSequence.database = Mongo::Connection.new.db("rubydaap")

class Track
  include Mongo

  def Track.count
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
    storage.count
  end

  def Track.get
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")    
    tracks = Array.new
    storage.find().to_a.each {|bson| tracks << Track.new(:hash => bson)}
    if block_given?
      tracks.each_with_index.map {|track,i| yield track, i}
    else
      tracks
    end
  end

  def Track.get_by_itunes_id(itunes_id)
    storage = MongoClient.new("localhost", 27017).db("rubydaap").collection("tracks")
    Track.new(:hash => storage.find({:itunes_id => itunes_id}))
  end

  def Track.get_all_dmap
    Track.get{|track,i| track.to_dmap(i)}
  end

  def Track.get_all_short_dmap
    Track.get{|track,i| track.to_short_dmap(i)}
  end

  def initialize(args)

    if args.has_key? :path

      @info = Hash.new
      @path = args[:path]
      @file = MP4Info.open(@path)
      lookup_table = Hash[*%w(
        album                   ALB
        apple_store_id          APID          
        artist                  ART           
        comment                 CMT           
        compilation             CPIL          
        copyright               CPRT          
        year                    DAY           
        disk_number_and_total   DISK          
        genre                   GNRE          
        grouping                GRP           
        title                   NAM           
        rating                  RTNG          
        tempo                   TMPO          
        encoder                 TOO           
        track_number_and_total  TRKN          
        track_number            TRKN
        track_total             TRKN
        author                  WRT           
        mpeg_version            VERSION       
        layer                   LAYER         
        bitrate                 BITRATE       
        frequency               FREQUENCY     
        bytes                   SIZE          
        total_seconds           SECS          
        minutes                 MM            
        seconds                 SS            
        milliseconds            MS            
        formatted_time          TIME          
        copyright               COPYRIGHT     
        encrypted               ENCRYPTED
        _id                     FAKE
        itunes_id               FAKE
      )]

      lookup_table.each_pair do |key, value|
    
        if key == "track_number"
          @info[key] = @file.send(value.to_sym)[0]
          next
        end

        if key == "track_total"
          @info[key] = @file.send(value.to_sym)[1]
          next
        end

        if key == "_id"
          @info[key] = Digest::MD5.file(@path).hexdigest
          next
        end

        if key == "itunes_id"
          @info[key] = MongoSequence[:global].next
          next
        end

        @info[key] = @file.send(value.to_sym)
      end

    elsif args.has_key? :hash
      @info = args[:hash] 
    end

  end

  def method_missing(sym, *args)
    if @info.has_key?(sym.to_s)
      @info[sym.to_s] || ""
    else
      raise "Metadata field '#{sym.to_s}' not found"
    end
  end

  def to_json
    json = {}
    @info.each_pair do |key, value|
      json[key] = self.send(key.to_sym)
    end
    json["_id"] = self._id
    json
  end

  def to_dmap(id)
    DMAP::Tag.new(:mlit,
      [
        DMAP::Tag.new(:mikd, 2),
        DMAP::Tag.new(:miid, self.itunes_id),
        DMAP::Tag.new(:minm, self.title),
        DMAP::Tag.new(:mper, self.itunes_id),
        DMAP::Tag.new(:asal, self.album),
        DMAP::Tag.new(:agrp, ""),
        DMAP::Tag.new(:asar, self.artist),
        DMAP::Tag.new(:asbr, self.bitrate),
        DMAP::Tag.new(:asbt, 0),
        DMAP::Tag.new(:ascm, ""),
        DMAP::Tag.new(:asco, 0),
        DMAP::Tag.new(:ascp, self.author),
        DMAP::Tag.new(:asda, Time.new.to_i),
        DMAP::Tag.new(:asdm, Time.new.to_i),
        DMAP::Tag.new(:asdc, 0),
        DMAP::Tag.new(:asdn, 0),
        DMAP::Tag.new(:asdb, 0),
        DMAP::Tag.new(:aseq, ""),
        DMAP::Tag.new(:asfm, "m4a"),
        DMAP::Tag.new(:asgn, self.genre),
        DMAP::Tag.new(:asdt, ""),
        DMAP::Tag.new(:asrv, 0),
        DMAP::Tag.new(:assr, 0),
        DMAP::Tag.new(:assz, self.bytes),
        DMAP::Tag.new(:asst, 0),
        DMAP::Tag.new(:assp, 0),
        DMAP::Tag.new(:astm, self.total_seconds * 1000),
        DMAP::Tag.new(:astc, self.track_total),
        DMAP::Tag.new(:astn, self.track_number),
        DMAP::Tag.new(:asur, 0),
        DMAP::Tag.new(:asyr, self.year),
        DMAP::Tag.new(:asdk, 0),
        DMAP::Tag.new(:asul, "")
      ]
    )
  end 

  def to_short_dmap(id)
    DMAP::Tag.new(:mlit,
      [
        DMAP::Tag.new(:mikd, 2),
        DMAP::Tag.new(:asdk, 0),
        DMAP::Tag.new(:miid, self.itunes_id),
        DMAP::Tag.new(:mcti, self.itunes_id),
        DMAP::Tag.new(:minm, self.title)
      ]
    )
  end

end
